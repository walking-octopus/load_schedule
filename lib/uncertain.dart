import 'dart:math' as math;

/// A type that represents uncertain data as a probability distribution
/// using sampling-based computation with conditional semantics.
///
/// `Uncertain` provides a way to work with probabilistic values
/// by representing them as sampling functions with a computation graph
/// for lazy evaluation and proper uncertainty-aware conditionals.
///
/// ## Example Usage
///
/// ```dart
/// final speed = Uncertain.normal(mean: 5.0, standardDeviation: 2.0);
///
/// if ((speed > 4.0).probability(exceeds: 0.9)) {
///   print("90% confident you're going fast");
/// }
///
/// // Implicit conditional (equivalent to .probability(exceeds: 0.5))
/// if ((speed > 4.0).implicitConditional()) {
///   print("More likely than not you're going fast");
/// }
/// ```
///
/// ## Performance Considerations
///
/// Uses Sequential Probability Ratio Test (SPRT) for efficient
/// hypothesis testing in conditionals. Sample counts are automatically
/// determined based on statistical significance rather than fixed numbers.
///
/// ## References
///
/// This library implements the approach described in:
///
/// James Bornholt, Todd Mytkowicz, and Kathryn S. McKinley.
/// "Uncertain<T>: A First-Order Type for Uncertain Data."
/// Architectural Support for Programming Languages and Operating Systems (ASPLOS), March 2014.
/// https://www.microsoft.com/en-us/research/publication/uncertaint-a-first-order-type-for-uncertain-data-2/
class Uncertain<T> extends Iterable<T> {
  /// The sampling function that generates values from this distribution.
  final T Function() sample;

  /// The computation graph node for lazy evaluation
  final ComputationNode<T> _node;

  /// Creates an uncertain value with the given sampling function.
  ///
  /// - Parameter sampler: A function that returns random samples from the distribution.
  Uncertain(this.sample)
    : _node = LeafNode<T>(id: _generateId(), sample: sample);

  /// Internal constructor with computation node for building computation graphs
  Uncertain._withNode(this._node)
    : sample = (() {
        T _sampler() {
          final context = SampleContext();
          return _node.evaluate(context);
        }

        return _sampler;
      })();

  static int _idCounter = 0;
  static int _generateId() => _idCounter++;

  /// Transforms an uncertain value by applying a function to each sample.
  ///
  /// - Parameter transform: A function to apply to each sampled value.
  /// - Returns: A new uncertain value with the transformed distribution.
  @override
  Uncertain<U> map<U>(U Function(T) transform) {
    return Uncertain<U>(() => transform(sample()));
  }

  /// Transforms an uncertain value by applying a function that returns another uncertain value.
  ///
  /// - Parameter transform: A function that takes a sample and returns an uncertain value.
  /// - Returns: A new uncertain value with the flattened distribution.
  Uncertain<U> flatMap<U>(Uncertain<U> Function(T) transform) {
    return Uncertain<U>(() => transform(sample()).sample());
  }

  /// Filters samples using rejection sampling.
  ///
  /// Only samples that satisfy the predicate are accepted.
  /// This method will keep sampling until a valid sample is found,
  /// so ensure the predicate has a reasonable acceptance rate.
  ///
  /// - Parameter predicate: A function that returns `true` for accepted samples.
  /// - Returns: A new uncertain value with the filtered distribution.
  Uncertain<T> filter(bool Function(T) predicate) {
    return Uncertain<T>(() {
      T value;
      do {
        value = sample();
      } while (!predicate(value));
      return value;
    });
  }

  /// Returns an iterator that produces infinite samples from this distribution.
  ///
  /// - Returns: An iterator that generates samples on demand.
  @override
  Iterator<T> get iterator => _UncertainIterator<T>(sample);
}

/// Iterator that produces infinite samples
class _UncertainIterator<T> implements Iterator<T> {
  final T Function() _sample;
  T? _current;

  _UncertainIterator(this._sample);

  @override
  T get current => _current as T;

  @override
  bool moveNext() {
    _current = _sample();
    return true;
  }
}

// MARK: - Computation Graph

/// Base class for computation graph nodes
abstract class ComputationNode<T> {
  T evaluate(SampleContext context);
}

/// Leaf node representing a sampling function
class LeafNode<T> extends ComputationNode<T> {
  final int id;
  final T Function() sample;

  LeafNode({required this.id, required this.sample});

  @override
  T evaluate(SampleContext context) {
    return context.getOrCompute(id, sample);
  }
}

/// Binary operation node
class BinaryOpNode<T> extends ComputationNode<T> {
  final ComputationNode<T> left;
  final ComputationNode<T> right;
  final T Function(T, T) operation;

  BinaryOpNode({
    required this.left,
    required this.right,
    required this.operation,
  });

  @override
  T evaluate(SampleContext context) {
    final leftValue = left.evaluate(context);
    final rightValue = right.evaluate(context);
    return operation(leftValue, rightValue);
  }
}

/// Comparison node for building evidence
class ComparisonNode<T extends Comparable<T>> {
  final ComputationNode<T> left;
  final T threshold;
  final bool Function(T, T) comparison;

  ComparisonNode({
    required this.left,
    required this.threshold,
    required this.comparison,
  });

  bool evaluate(SampleContext context) {
    final leftValue = left.evaluate(context);
    return comparison(leftValue, threshold);
  }
}

/// Equality node for building evidence
class EqualityNode<T> {
  final ComputationNode<T> left;
  final T threshold;
  final bool Function(T, T) comparison;

  EqualityNode({
    required this.left,
    required this.threshold,
    required this.comparison,
  });

  bool evaluate(SampleContext context) {
    final leftValue = left.evaluate(context);
    return comparison(leftValue, threshold);
  }
}

/// Context for maintaining consistent samples across a computation
class SampleContext {
  final Map<int, dynamic> _cache = {};

  T getOrCompute<T>(int id, T Function() compute) {
    if (_cache.containsKey(id)) {
      return _cache[id] as T;
    }
    final value = compute();
    _cache[id] = value;
    return value;
  }
}

// MARK: - Operators

/// Extension for numeric operations
extension UncertainNumeric<T extends num> on Uncertain<T> {
  /// Adds two uncertain values - builds computation graph
  Uncertain<T> operator +(Object other) {
    if (other is Uncertain<T>) {
      final newNode = BinaryOpNode<T>(
        left: _node,
        right: other._node,
        operation: (a, b) => (a + b) as T,
      );
      return Uncertain<T>._withNode(newNode);
    } else if (other is T) {
      return this + Uncertain<T>(() => other);
    } else if (T == double && other is num) {
      // Handle int addition with Uncertain<double>
      return this + Uncertain<T>(() => other.toDouble() as T);
    }
    throw ArgumentError('Unsupported type for addition');
  }

  /// Subtracts two uncertain values - builds computation graph
  Uncertain<T> operator -(Object other) {
    if (other is Uncertain<T>) {
      final newNode = BinaryOpNode<T>(
        left: _node,
        right: other._node,
        operation: (a, b) => (a - b) as T,
      );
      return Uncertain<T>._withNode(newNode);
    } else if (other is T) {
      return this - Uncertain<T>(() => other);
    } else if (T == double && other is num) {
      // Handle int subtraction with Uncertain<double>
      return this - Uncertain<T>(() => other.toDouble() as T);
    }
    throw ArgumentError('Unsupported type for subtraction');
  }

  /// Multiplies two uncertain values - builds computation graph
  Uncertain<T> operator *(Object other) {
    if (other is Uncertain<T>) {
      final newNode = BinaryOpNode<T>(
        left: _node,
        right: other._node,
        operation: (a, b) => (a * b) as T,
      );
      return Uncertain<T>._withNode(newNode);
    } else if (other is T) {
      return this * Uncertain<T>(() => other);
    } else if (T == double && other is num) {
      // Handle int multiplication with Uncertain<double>
      return this * Uncertain<T>(() => other.toDouble() as T);
    }
    throw ArgumentError('Unsupported type for multiplication');
  }

  /// Divides two uncertain values - builds computation graph
  Uncertain<T> operator /(Object other) {
    if (other is Uncertain<T>) {
      final newNode = BinaryOpNode<T>(
        left: _node,
        right: other._node,
        operation: (a, b) => (a / b) as T,
      );
      return Uncertain<T>._withNode(newNode);
    } else if (other is T) {
      return this / Uncertain<T>(() => other);
    } else if (T == double && other is num) {
      // Handle int division with Uncertain<double>
      return this / Uncertain<T>(() => other.toDouble() as T);
    }
    throw ArgumentError('Unsupported type for division');
  }

  /// Negation operator
  Uncertain<T> operator -() {
    return map((x) => (-x) as T);
  }
}

/// Extension for comparable operations
extension UncertainComparable<T extends Comparable<T>> on Uncertain<T> {
  /// Returns uncertain boolean evidence that this value is greater than threshold
  Uncertain<bool> operator >(T threshold) {
    final comparisonNode = ComparisonNode<T>(
      left: _node,
      threshold: threshold,
      comparison: (a, b) => a.compareTo(b) > 0,
    );

    return Uncertain<bool>._withNode(
      LeafNode<bool>(
        id: Uncertain._generateId(),
        sample: () {
          final context = SampleContext();
          return comparisonNode.evaluate(context);
        },
      ),
    );
  }

  /// Returns uncertain boolean evidence that this value is less than threshold
  Uncertain<bool> operator <(T threshold) {
    final comparisonNode = ComparisonNode<T>(
      left: _node,
      threshold: threshold,
      comparison: (a, b) => a.compareTo(b) < 0,
    );

    return Uncertain<bool>._withNode(
      LeafNode<bool>(
        id: Uncertain._generateId(),
        sample: () {
          final context = SampleContext();
          return comparisonNode.evaluate(context);
        },
      ),
    );
  }

  /// Returns uncertain boolean evidence that this value is greater than or equal to threshold
  Uncertain<bool> operator >=(T threshold) {
    final comparisonNode = ComparisonNode<T>(
      left: _node,
      threshold: threshold,
      comparison: (a, b) => a.compareTo(b) >= 0,
    );

    return Uncertain<bool>._withNode(
      LeafNode<bool>(
        id: Uncertain._generateId(),
        sample: () {
          final context = SampleContext();
          return comparisonNode.evaluate(context);
        },
      ),
    );
  }

  /// Returns uncertain boolean evidence that this value is less than or equal to threshold
  Uncertain<bool> operator <=(T threshold) {
    final comparisonNode = ComparisonNode<T>(
      left: _node,
      threshold: threshold,
      comparison: (a, b) => a.compareTo(b) <= 0,
    );

    return Uncertain<bool>._withNode(
      LeafNode<bool>(
        id: Uncertain._generateId(),
        sample: () {
          final context = SampleContext();
          return comparisonNode.evaluate(context);
        },
      ),
    );
  }

  /// Compares two uncertain values
  Uncertain<bool> gt(Uncertain<T> other) {
    return Uncertain<bool>(() => sample().compareTo(other.sample()) > 0);
  }

  /// Compares two uncertain values
  Uncertain<bool> lt(Uncertain<T> other) {
    return Uncertain<bool>(() => sample().compareTo(other.sample()) < 0);
  }
}

/// Extension for equality operations
extension UncertainEquatable<T> on Uncertain<T> {
  /// Returns uncertain boolean evidence that this value equals a given value
  Uncertain<bool> eq(T value) {
    final equalityNode = EqualityNode<T>(
      left: _node,
      threshold: value,
      comparison: (a, b) => a == b,
    );

    return Uncertain<bool>._withNode(
      LeafNode<bool>(
        id: Uncertain._generateId(),
        sample: () {
          final context = SampleContext();
          return equalityNode.evaluate(context);
        },
      ),
    );
  }

  /// Returns uncertain boolean evidence that this value does not equal a given value
  Uncertain<bool> neq(T value) {
    final equalityNode = EqualityNode<T>(
      left: _node,
      threshold: value,
      comparison: (a, b) => a != b,
    );

    return Uncertain<bool>._withNode(
      LeafNode<bool>(
        id: Uncertain._generateId(),
        sample: () {
          final context = SampleContext();
          return equalityNode.evaluate(context);
        },
      ),
    );
  }

  /// Compares two uncertain values for equality
  Uncertain<bool> equals(Uncertain<T> other) {
    return Uncertain<bool>(() => sample() == other.sample());
  }

  /// Compares two uncertain values for inequality
  Uncertain<bool> notEquals(Uncertain<T> other) {
    return Uncertain<bool>(() => sample() != other.sample());
  }
}

/// Extension for boolean operations
extension UncertainBoolean on Uncertain<bool> {
  /// Logical NOT operator for uncertain boolean values
  Uncertain<bool> operator ~() {
    return Uncertain<bool>(() {
      final context = SampleContext();
      return !_node.evaluate(context);
    });
  }

  /// Logical AND operator for uncertain boolean values
  Uncertain<bool> and(Uncertain<bool> other) {
    return Uncertain<bool>(() {
      final context = SampleContext();
      return _node.evaluate(context) && other._node.evaluate(context);
    });
  }

  /// Logical OR operator for uncertain boolean values
  Uncertain<bool> or(Uncertain<bool> other) {
    return Uncertain<bool>(() {
      final context = SampleContext();
      return _node.evaluate(context) || other._node.evaluate(context);
    });
  }

  /// Implicit conditional (equivalent to probability(exceeds: 0.5))
  bool implicitConditional() {
    return probability(exceeds: 0.5);
  }

  /// Tests if this uncertain boolean meets a probability threshold using SPRT.
  ///
  /// Uses Sequential Probability Ratio Test for efficient hypothesis testing.
  ///
  /// - Parameters:
  ///   - exceeds: The probability threshold (e.g., 0.9 for 90% confidence)
  ///   - alpha: Type I error rate (default 0.05)
  ///   - beta: Type II error rate (default 0.05)
  ///   - maxSamples: Maximum number of samples before giving up (default 10000)
  /// - Returns: true if evidence supports the hypothesis with given confidence
  bool probability({
    required double exceeds,
    double alpha = 0.05,
    double beta = 0.05,
    int maxSamples = 10000,
  }) {
    assert(
      exceeds >= 0.0 && exceeds <= 1.0,
      'Threshold must be between 0 and 1',
    );
    assert(alpha > 0.0 && alpha < 1.0, 'Alpha must be between 0 and 1');
    assert(beta > 0.0 && beta < 1.0, 'Beta must be between 0 and 1');

    // SPRT thresholds
    final upperBound = (1.0 - beta) / alpha;
    final lowerBound = beta / (1.0 - alpha);

    int successes = 0;
    int trials = 0;
    double likelihoodRatio = 1.0;

    while (trials < maxSamples) {
      final result = sample();
      trials++;

      if (result) {
        successes++;
        // Update likelihood ratio: P(x|H1) / P(x|H0)
        // H1: p = exceeds, H0: p = 1 - exceeds (or some null hypothesis)
        likelihoodRatio *= exceeds / (1.0 - exceeds);
      } else {
        likelihoodRatio *= (1.0 - exceeds) / exceeds;
      }

      // Check SPRT decision boundaries
      if (likelihoodRatio >= upperBound) {
        return true; // Accept H1: probability exceeds threshold
      } else if (likelihoodRatio <= lowerBound) {
        return false; // Reject H1: probability does not exceed threshold
      }
    }

    // Fallback: if SPRT doesn't converge, use simple frequency test
    return (successes / trials) > exceeds;
  }
}

// MARK: - Distributions

/// Factory methods for creating distributions
extension UncertainDistributions on Uncertain {
  /// Creates a point-mass distribution (certain value).
  ///
  /// - Parameter value: The certain value to always return.
  /// - Returns: A new uncertain value that always returns the same value.
  static Uncertain<T> point<T>(T value) {
    return Uncertain<T>(() => value);
  }

  /// Creates a mixture of distributions with optional weights.
  ///
  /// - Parameters:
  ///   - components: A list of distributions to mix.
  ///   - weights: An optional list of weights corresponding to each distribution.
  ///              If `null`, uses uniform weights.
  /// - Returns: A new uncertain value representing the mixture distribution.
  static Uncertain<T> mixture<T>(
    List<Uncertain<T>> components, {
    List<double>? weights,
  }) {
    assert(components.isNotEmpty, 'At least one component required');

    if (components.length == 1) {
      return components[0];
    }

    final w = weights ?? List<double>.filled(components.length, 1.0);

    assert(
      components.length == w.length,
      'Weights count must match components count',
    );

    final total = w.reduce((a, b) => a + b);
    final normalized = w.map((weight) => weight / total).toList();

    // Build cumulative distribution
    final cumulative = <double>[];
    var sum = 0.0;
    for (final weight in normalized) {
      sum += weight;
      cumulative.add(sum);
    }

    return Uncertain<T>(() {
      final r = math.Random().nextDouble();
      final idx = cumulative.indexWhere((c) => r <= c);
      return components[idx == -1 ? components.length - 1 : idx].sample();
    });
  }

  /// Creates an empirical distribution from observed data.
  ///
  /// - Parameter data: A list of observed values.
  /// - Returns: A new uncertain value that randomly selects from the provided data, or null if data is empty.
  static Uncertain<T>? empirical<T>(List<T> data) {
    if (data.isEmpty) return null;
    final random = math.Random();
    return Uncertain<T>(() => data[random.nextInt(data.length)]);
  }

  /// Creates a categorical distribution from value-probability pairs.
  ///
  /// - Parameter probabilities: A map from values to their probabilities.
  /// - Returns: A new uncertain value representing the categorical distribution, or null if input is empty.
  static Uncertain<T>? categorical<T>(Map<T, double> probabilities) {
    if (probabilities.isEmpty) return null;

    final total = probabilities.values.reduce((a, b) => a + b);
    final normalized = probabilities.map((k, v) => MapEntry(k, v / total));

    // Sort and build cumulative distribution
    final sorted = normalized.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final cumulative = <MapEntry<T, double>>[];
    var sum = 0.0;
    for (final entry in sorted) {
      sum += entry.value;
      cumulative.add(MapEntry(entry.key, sum));
    }

    return Uncertain<T>(() {
      final r = math.Random().nextDouble();
      final entry = cumulative.firstWhere(
        (e) => r <= e.value,
        orElse: () => cumulative.last,
      );
      return entry.key;
    });
  }
}

/// Integer distribution extensions
extension UncertainInt on Uncertain<int> {
  /// Creates a binomial distribution.
  ///
  /// - Parameters:
  ///   - trials: The number of trials.
  ///   - probability: The probability of success on each trial.
  /// - Returns: A new uncertain value with a binomial distribution.
  static Uncertain<int> binomial({
    required int trials,
    required double probability,
  }) {
    final random = math.Random();
    return Uncertain<int>(() {
      var count = 0;
      for (var i = 0; i < trials; i++) {
        if (random.nextDouble() < probability) {
          count++;
        }
      }
      return count;
    });
  }

  /// Creates a Poisson distribution.
  ///
  /// - Parameter lambda: The rate parameter.
  /// - Returns: A new uncertain value with a Poisson distribution.
  static Uncertain<int> poisson({required double lambda}) {
    final random = math.Random();
    return Uncertain<int>(() {
      final l = math.exp(-lambda);
      var k = 0;
      var p = 1.0;
      do {
        k++;
        p *= random.nextDouble();
      } while (p > l);
      return k - 1;
    });
  }
}

/// Double distribution extensions
extension UncertainDouble on Uncertain<double> {
  /// Creates a normal (Gaussian) distribution.
  ///
  /// - Parameters:
  ///   - mean: The mean of the distribution.
  ///   - standardDeviation: The standard deviation of the distribution.
  /// - Returns: A new uncertain value with a normal distribution.
  static Uncertain<double> normal({
    required double mean,
    required double standardDeviation,
  }) {
    final random = math.Random();
    return Uncertain<double>(() {
      // Box-Muller transform for normal distribution
      final u1 = 0.001 + random.nextDouble() * 0.998; // Avoid exactly 0 or 1
      final u2 = 0.001 + random.nextDouble() * 0.998;
      final z0 = math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2);
      return mean + standardDeviation * z0;
    });
  }

  /// Creates a uniform distribution.
  ///
  /// - Parameters:
  ///   - min: The minimum value.
  ///   - max: The maximum value.
  /// - Returns: A new uncertain value with a uniform distribution.
  static Uncertain<double> uniform({required double min, required double max}) {
    final random = math.Random();
    return Uncertain<double>(() => min + random.nextDouble() * (max - min));
  }

  /// Creates an exponential distribution.
  ///
  /// - Parameter rate: The rate parameter (lambda).
  /// - Returns: A new uncertain value with an exponential distribution.
  static Uncertain<double> exponential({required double rate}) {
    final random = math.Random();
    return Uncertain<double>(() => -math.log(random.nextDouble()) / rate);
  }

  /// Creates a Bernoulli distribution.
  ///
  /// - Parameter probability: The probability of success.
  /// - Returns: A new uncertain boolean value.
  static Uncertain<bool> bernoulli({required double probability}) {
    final random = math.Random();
    return Uncertain<bool>(() => random.nextDouble() < probability);
  }

  /// Creates a Kumaraswamy distribution.
  ///
  /// - Parameters:
  ///   - a: The first shape parameter (must be > 0).
  ///   - b: The second shape parameter (must be > 0).
  /// - Returns: A new uncertain value with a Kumaraswamy distribution in range [0, 1].
  static Uncertain<double> kumaraswamy({required double a, required double b}) {
    assert(
      a > 0 && b > 0,
      'Kumaraswamy distribution parameters must be positive',
    );

    final reciprocalA = 1.0 / a;
    final reciprocalB = 1.0 / b;
    final random = math.Random();

    return Uncertain<double>(() {
      final u = random.nextDouble();
      return math
          .pow(1.0 - math.pow(1.0 - u, reciprocalB), reciprocalA)
          .toDouble();
    });
  }

  /// Creates a Rayleigh distribution.
  ///
  /// The Rayleigh distribution models the magnitude of a 2D vector whose components
  /// are normally distributed. It's commonly used for modeling distances from a center point.
  ///
  /// - Parameter scale: The scale parameter (must be > 0).
  /// - Returns: A new uncertain value with a Rayleigh distribution.
  static Uncertain<double> rayleigh({required double scale}) {
    assert(scale > 0, 'Rayleigh distribution scale parameter must be positive');

    final random = math.Random();
    return Uncertain<double>(() {
      final u = random.nextDouble();
      return scale * math.sqrt(-2.0 * math.log(1.0 - u));
    });
  }

  /// Estimates the log-likelihood of a value using kernel density estimation.
  ///
  /// - Parameters:
  ///   - value: The value to evaluate.
  ///   - sampleCount: The number of samples to use for estimation.
  ///   - bandwidth: The bandwidth parameter for the kernel.
  /// - Returns: The estimated log-likelihood.
  double logLikelihood(
    double value, {
    int sampleCount = 1000,
    double bandwidth = 1.0,
  }) {
    final samples = take(sampleCount);

    double kernel(double x, double xi) {
      return math.exp(-0.5 * math.pow((x - xi) / bandwidth, 2)) /
          (bandwidth * math.sqrt(2 * math.pi));
    }

    final density =
        samples.map((xi) => kernel(value, xi)).reduce((a, b) => a + b) /
        sampleCount;
    return math.log(density);
  }
}

// MARK: - Statistics

/// Extension for hashable statistics
extension UncertainHashableStats<T> on Uncertain<T> {
  /// Returns the most frequently occurring value in the distribution.
  ///
  /// - Parameter sampleCount: The number of samples to use for estimation.
  /// - Returns: The mode (most frequent value), or `null` if no samples are available.
  T? mode({int sampleCount = 1000}) {
    final samples = take(sampleCount).toList();
    if (samples.isEmpty) return null;

    final counts = <T, int>{};
    for (final sample in samples) {
      counts[sample] = (counts[sample] ?? 0) + 1;
    }

    var maxCount = 0;
    T? modeValue;
    counts.forEach((value, count) {
      if (count > maxCount) {
        maxCount = count;
        modeValue = value;
      }
    });

    return modeValue;
  }

  /// Returns a histogram showing the frequency of each value.
  ///
  /// - Parameter sampleCount: The number of samples to use for estimation.
  /// - Returns: A map from values to their occurrence counts.
  Map<T, int> histogram({int sampleCount = 1000}) {
    final samples = take(sampleCount);
    final counts = <T, int>{};
    for (final sample in samples) {
      counts[sample] = (counts[sample] ?? 0) + 1;
    }
    return counts;
  }

  /// Calculates the empirical entropy of the distribution.
  ///
  /// - Parameter sampleCount: The number of samples to use for estimation.
  /// - Returns: The entropy in bits.
  double entropy({int sampleCount = 1000}) {
    final samples = take(sampleCount).toList();
    final counts = <T, int>{};
    for (final sample in samples) {
      counts[sample] = (counts[sample] ?? 0) + 1;
    }

    final total = samples.length.toDouble();
    var entropy = 0.0;

    for (var count in counts.values) {
      final p = count / total;
      if (p > 0) {
        entropy -= p * (math.log(p) / math.ln2);
      }
    }

    return entropy;
  }
}

/// Extension for numeric statistics
extension UncertainNumericStats<T extends num> on Uncertain<T> {
  /// Calculates the expected value (mean) of the distribution.
  ///
  /// - Parameter sampleCount: The number of samples to use for estimation.
  /// - Returns: The expected value.
  double expectedValue({int sampleCount = 1000}) {
    final samples = take(sampleCount);
    var sum = 0.0;
    for (final sample in samples) {
      sum += sample.toDouble();
    }
    return sum / sampleCount;
  }

  /// Calculates the standard deviation of the distribution.
  ///
  /// - Parameter sampleCount: The number of samples to use for estimation.
  /// - Returns: The standard deviation.
  double standardDeviation({int sampleCount = 1000}) {
    final samples = take(sampleCount).toList();
    final mean = expectedValue(sampleCount: sampleCount);

    var variance = 0.0;
    for (final sample in samples) {
      final diff = sample.toDouble() - mean;
      variance += diff * diff;
    }
    variance /= sampleCount;

    return math.sqrt(variance);
  }

  /// Calculates the skewness of the distribution.
  ///
  /// - Parameter sampleCount: The number of samples to use for estimation.
  /// - Returns: The skewness value.
  double skewness({int sampleCount = 1000}) {
    final samples = take(sampleCount).toList();
    final mean = expectedValue(sampleCount: sampleCount);
    final std = standardDeviation(sampleCount: sampleCount);

    var skew = 0.0;
    for (final sample in samples) {
      skew += math.pow(sample.toDouble() - mean, 3);
    }

    return skew / sampleCount / math.pow(std, 3);
  }

  /// Calculates the kurtosis of the distribution.
  ///
  /// - Parameter sampleCount: The number of samples to use for estimation.
  /// - Returns: The excess kurtosis value.
  double kurtosis({int sampleCount = 1000}) {
    final samples = take(sampleCount).toList();
    final mean = expectedValue(sampleCount: sampleCount);
    final std = standardDeviation(sampleCount: sampleCount);

    var kurt = 0.0;
    for (final sample in samples) {
      kurt += math.pow(sample.toDouble() - mean, 4);
    }

    return kurt / sampleCount / math.pow(std, 4) - 3.0;
  }
}

/// Extension for comparable numeric statistics
extension UncertainComparableNumericStats<T extends Comparable<T>>
    on Uncertain<T> {
  /// Calculates the confidence interval for the distribution.
  ///
  /// - Parameters:
  ///   - confidence: The confidence level (e.g., 0.95 for 95% CI).
  ///   - sampleCount: The number of samples to use for estimation.
  /// - Returns: A record containing the lower and upper bounds of the confidence interval.
  ({T lower, T upper}) confidenceInterval({
    double confidence = 0.95,
    int sampleCount = 1000,
  }) {
    final samples = take(sampleCount).toList()..sort();
    final alpha = 1.0 - confidence;
    final lowerIndex = (alpha / 2.0 * samples.length).floor();
    final upperIndex = ((1.0 - alpha / 2.0) * samples.length).floor() - 1;

    final safeUpperIndex = upperIndex.clamp(0, samples.length - 1);
    final safeLowerIndex = lowerIndex.clamp(0, samples.length - 1);

    return (lower: samples[safeLowerIndex], upper: samples[safeUpperIndex]);
  }

  /// Estimates the cumulative distribution function (CDF) at a given value.
  ///
  /// - Parameters:
  ///   - value: The value at which to evaluate the CDF.
  ///   - sampleCount: The number of samples to use for estimation.
  /// - Returns: The CDF value (probability that a sample is ≤ value).
  double cdf({required T value, int sampleCount = 1000}) {
    final samples = take(sampleCount);
    var successes = 0;
    for (final s in samples) {
      if (s.compareTo(value) <= 0) {
        successes++;
      }
    }
    return successes / sampleCount;
  }

  /// Estimates a quantile (percentile) of the distribution.
  ///
  /// - Parameters:
  ///   - quantile: The quantile to estimate (e.g., 0.5 for median).
  ///   - sampleCount: The number of samples to use for estimation.
  /// - Returns: The estimated quantile value.
  T quantile({required double quantile, int sampleCount = 1000}) {
    assert(
      quantile >= 0.0 && quantile <= 1.0,
      'Quantile must be between 0 and 1',
    );

    final samples = take(sampleCount).toList()..sort();
    final index = (quantile * (samples.length - 1)).round();
    return samples[index.clamp(0, samples.length - 1)];
  }

  /// Calculates the median of the distribution.
  ///
  /// - Parameter sampleCount: The number of samples to use for estimation.
  /// - Returns: The median value.
  T median({int sampleCount = 1000}) {
    return quantile(quantile: 0.5, sampleCount: sampleCount);
  }
}
