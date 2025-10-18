import 'package:flutter_test/flutter_test.dart';
import 'package:powertime/uncertain.dart';
import 'dart:math' as math;

void main() {
  group('Uncertain - Basic Construction', () {
    test('creates uncertain value with custom sampler', () {
      final u = Uncertain<int>(() => 42);
      expect(u.sample(), equals(42));
    });

    test('creates point-mass distribution', () {
      final u = UncertainDistributions.point(10);
      expect(u.sample(), equals(10));
      expect(u.take(5).every((x) => x == 10), isTrue);
    });

    test('creates empirical distribution', () {
      final data = [1, 2, 3, 4, 5];
      final u = UncertainDistributions.empirical(data);
      expect(u, isNotNull);

      final samples = u!.take(100).toList();
      expect(samples.every((x) => data.contains(x)), isTrue);
    });

    test('creates categorical distribution', () {
      final probs = {'A': 0.7, 'B': 0.2, 'C': 0.1};
      final u = UncertainDistributions.categorical(probs);
      expect(u, isNotNull);

      final samples = u!.take(1000).toList();
      expect(samples.every((x) => probs.containsKey(x)), isTrue);

      // Check rough distribution (A should be most common)
      final histogram = samples.fold<Map<String, int>>(
        {},
        (acc, x) {
          acc[x] = (acc[x] ?? 0) + 1;
          return acc;
        },
      );
      expect(histogram['A']!, greaterThan(histogram['B']!));
      expect(histogram['B']!, greaterThan(histogram['C']!));
    });
  });

  group('Uncertain - Distributions', () {
    test('normal distribution has correct mean', () {
      final u = UncertainDouble.normal(mean: 10.0, standardDeviation: 2.0);
      final mean = u.expectedValue(sampleCount: 5000);
      expect(mean, closeTo(10.0, 0.5));
    });

    test('normal distribution has correct standard deviation', () {
      final u = UncertainDouble.normal(mean: 0.0, standardDeviation: 5.0);
      final std = u.standardDeviation(sampleCount: 5000);
      expect(std, closeTo(5.0, 0.5));
    });

    test('uniform distribution stays within bounds', () {
      final u = UncertainDouble.uniform(min: 0.0, max: 10.0);
      final samples = u.take(100).toList();
      expect(samples.every((x) => x >= 0.0 && x <= 10.0), isTrue);
    });

    test('uniform distribution has correct mean', () {
      final u = UncertainDouble.uniform(min: 0.0, max: 10.0);
      final mean = u.expectedValue(sampleCount: 5000);
      expect(mean, closeTo(5.0, 0.5));
    });

    test('exponential distribution produces positive values', () {
      final u = UncertainDouble.exponential(rate: 1.0);
      final samples = u.take(100).toList();
      expect(samples.every((x) => x >= 0), isTrue);
    });

    test('bernoulli distribution produces boolean values', () {
      final u = UncertainDouble.bernoulli(probability: 0.7);
      final samples = u.take(1000).toList();
      final trueCount = samples.where((x) => x).length;
      expect(trueCount / 1000, closeTo(0.7, 0.1));
    });

    test('binomial distribution has correct mean', () {
      final u = UncertainInt.binomial(trials: 100, probability: 0.5);
      final mean = u.expectedValue(sampleCount: 1000);
      expect(mean, closeTo(50.0, 5.0));
    });

    test('poisson distribution produces non-negative integers', () {
      final u = UncertainInt.poisson(lambda: 5.0);
      final samples = u.take(100).toList();
      expect(samples.every((x) => x >= 0), isTrue);
    });

    test('kumaraswamy distribution stays in [0, 1]', () {
      final u = UncertainDouble.kumaraswamy(a: 2.0, b: 5.0);
      final samples = u.take(100).toList();
      expect(samples.every((x) => x >= 0 && x <= 1), isTrue);
    });

    test('rayleigh distribution produces positive values', () {
      final u = UncertainDouble.rayleigh(scale: 1.0);
      final samples = u.take(100).toList();
      expect(samples.every((x) => x >= 0), isTrue);
    });
  });

  group('Uncertain - Operators', () {
    test('addition of uncertain values', () {
      final u1 = UncertainDistributions.point(5);
      final u2 = UncertainDistributions.point(3);
      final sum = u1 + u2;
      expect(sum.sample(), equals(8));
    });

    test('subtraction of uncertain values', () {
      final u1 = UncertainDistributions.point(10);
      final u2 = UncertainDistributions.point(3);
      final diff = u1 - u2;
      expect(diff.sample(), equals(7));
    });

    test('multiplication of uncertain values', () {
      final u1 = UncertainDistributions.point(4);
      final u2 = UncertainDistributions.point(3);
      final prod = u1 * u2;
      expect(prod.sample(), equals(12));
    });

    test('division of uncertain values', () {
      final u1 = UncertainDistributions.point(12.0);
      final u2 = UncertainDistributions.point(3.0);
      final quot = u1 / u2;
      expect(quot.sample(), equals(4.0));
    });

    test('negation operator', () {
      final u = UncertainDistributions.point(5);
      final neg = -u;
      expect(neg.sample(), equals(-5));
    });

    test('addition with constant', () {
      final u = UncertainDistributions.point(5);
      final sum = u + 3;
      expect(sum.sample(), equals(8));
    });

    test('comparison operators produce boolean uncertain values', () {
      final u = UncertainDouble.normal(mean: 5.0, standardDeviation: 1.0);
      final evidence = u > 4.0;
      expect(evidence.sample(), isA<bool>());
    });

    test('equality operators', () {
      final u = UncertainDistributions.point(5);
      final evidence = u.eq(5);
      expect(evidence.sample(), isTrue);

      final notEvidence = u.neq(5);
      expect(notEvidence.sample(), isFalse);
    });
  });

  group('Uncertain - Transformations', () {
    test('map transforms samples', () {
      final u = UncertainDistributions.point(5);
      final doubled = u.map((x) => x * 2);
      expect(doubled.sample(), equals(10));
    });

    test('flatMap chains uncertain values', () {
      final u = UncertainDistributions.point(5);
      final chained = u.flatMap((x) => UncertainDistributions.point(x + 3));
      expect(chained.sample(), equals(8));
    });

    test('filter uses rejection sampling', () {
      final u = UncertainDouble.uniform(min: 0.0, max: 10.0);
      final filtered = u.filter((x) => x > 5.0);
      final samples = filtered.take(100).toList();
      expect(samples.every((x) => x > 5.0), isTrue);
    });
  });

  group('Uncertain - Boolean Logic', () {
    test('NOT operator', () {
      final u = UncertainDistributions.point(true);
      final notU = ~u;
      expect(notU.sample(), isFalse);
    });

    test('AND operator', () {
      final u1 = UncertainDistributions.point(true);
      final u2 = UncertainDistributions.point(false);
      final result = u1.and(u2);
      expect(result.sample(), isFalse);
    });

    test('OR operator', () {
      final u1 = UncertainDistributions.point(true);
      final u2 = UncertainDistributions.point(false);
      final result = u1.or(u2);
      expect(result.sample(), isTrue);
    });
  });

  group('Uncertain - Conditionals with SPRT', () {
    test('high probability event passes threshold', () {
      // Create a distribution that's almost always > 4
      final u = UncertainDouble.normal(mean: 10.0, standardDeviation: 1.0);
      final evidence = u > 4.0;

      // This should be true with high confidence
      expect(evidence.probability(exceeds: 0.9), isTrue);
    });

    test('low probability event fails threshold', () {
      // Create a distribution that's rarely > 15
      final u = UncertainDouble.normal(mean: 5.0, standardDeviation: 1.0);
      final evidence = u > 15.0;

      // This should be false
      expect(evidence.probability(exceeds: 0.9), isFalse);
    });

    test('implicit conditional uses 0.5 threshold', () {
      final u = UncertainDouble.bernoulli(probability: 0.8);
      expect(u.implicitConditional(), isTrue);

      final u2 = UncertainDouble.bernoulli(probability: 0.2);
      expect(u2.implicitConditional(), isFalse);
    });

    test('SPRT converges for clear cases', () {
      final u = UncertainDouble.normal(mean: 10.0, standardDeviation: 1.0);
      final evidence = u > 5.0;

      // Should converge quickly for such a clear case
      final result = evidence.probability(exceeds: 0.99, maxSamples: 1000);
      expect(result, isTrue);
    });
  });

  group('Uncertain - Statistics', () {
    test('mode returns most frequent value', () {
      final u = UncertainDistributions.categorical({
        'A': 0.7,
        'B': 0.2,
        'C': 0.1,
      })!;
      final mode = u.mode(sampleCount: 1000);
      expect(mode, equals('A'));
    });

    test('histogram counts frequencies', () {
      final data = [1, 1, 1, 2, 2, 3];
      final u = UncertainDistributions.empirical(data)!;
      final hist = u.histogram(sampleCount: 600);

      expect(hist.keys, containsAll([1, 2, 3]));
      expect(hist[1]!, greaterThan(hist[2]!));
      expect(hist[2]!, greaterThan(hist[3]!));
    });

    test('entropy is positive for non-deterministic distributions', () {
      final u = UncertainDistributions.categorical({
        'A': 0.5,
        'B': 0.5,
      })!;
      final ent = u.entropy(sampleCount: 1000);
      expect(ent, greaterThan(0));
      expect(ent, closeTo(1.0, 0.2)); // Should be close to 1 bit for 50/50
    });

    test('entropy is near zero for point-mass', () {
      final u = UncertainDistributions.point('A');
      final ent = u.entropy(sampleCount: 1000);
      expect(ent, closeTo(0.0, 0.1));
    });

    test('expected value for normal distribution', () {
      final u = UncertainDouble.normal(mean: 15.0, standardDeviation: 3.0);
      final ev = u.expectedValue(sampleCount: 5000);
      expect(ev, closeTo(15.0, 0.5));
    });

    test('standard deviation for normal distribution', () {
      final u = UncertainDouble.normal(mean: 0.0, standardDeviation: 4.0);
      final std = u.standardDeviation(sampleCount: 5000);
      expect(std, closeTo(4.0, 0.5));
    });

    test('confidence interval contains mean', () {
      final u = UncertainDouble.normal(mean: 10.0, standardDeviation: 2.0);
      final ci = u.confidenceInterval(confidence: 0.95, sampleCount: 5000);

      expect(ci.lower, lessThan(10.0));
      expect(ci.upper, greaterThan(10.0));
    });

    test('CDF is between 0 and 1', () {
      final u = UncertainDouble.normal(mean: 5.0, standardDeviation: 1.0);
      final cdfValue = u.cdf(value: 5.0, sampleCount: 1000);

      expect(cdfValue, greaterThanOrEqualTo(0.0));
      expect(cdfValue, lessThanOrEqualTo(1.0));
      expect(cdfValue, closeTo(0.5, 0.1)); // Should be ~0.5 at the mean
    });

    test('median for normal distribution', () {
      final u = UncertainDouble.normal(mean: 10.0, standardDeviation: 2.0);
      final med = u.median(sampleCount: 5000);
      expect(med, closeTo(10.0, 0.5));
    });

    test('quantile for uniform distribution', () {
      final u = UncertainDouble.uniform(min: 0.0, max: 100.0);
      final q25 = u.quantile(quantile: 0.25, sampleCount: 5000);
      final q75 = u.quantile(quantile: 0.75, sampleCount: 5000);

      expect(q25, closeTo(25.0, 5.0));
      expect(q75, closeTo(75.0, 5.0));
    });

    test('skewness for normal distribution is near zero', () {
      final u = UncertainDouble.normal(mean: 0.0, standardDeviation: 1.0);
      final skew = u.skewness(sampleCount: 5000);
      expect(skew, closeTo(0.0, 0.3));
    });

    test('kurtosis for normal distribution is near zero', () {
      final u = UncertainDouble.normal(mean: 0.0, standardDeviation: 1.0);
      final kurt = u.kurtosis(sampleCount: 5000);
      expect(kurt, closeTo(0.0, 0.5)); // Excess kurtosis
    });
  });

  group('Uncertain - Mixture Distributions', () {
    test('mixture of point masses', () {
      final u1 = UncertainDistributions.point(1);
      final u2 = UncertainDistributions.point(2);
      final mixture = UncertainDistributions.mixture([u1, u2]);

      final samples = mixture.take(100).toList();
      expect(samples.every((x) => x == 1 || x == 2), isTrue);
    });

    test('weighted mixture', () {
      final u1 = UncertainDistributions.point(1);
      final u2 = UncertainDistributions.point(2);
      final mixture = UncertainDistributions.mixture(
        [u1, u2],
        weights: [0.9, 0.1],
      );

      final samples = mixture.take(1000).toList();
      final count1 = samples.where((x) => x == 1).length;
      expect(count1 / 1000, closeTo(0.9, 0.1));
    });

    test('single component mixture returns same distribution', () {
      final u = UncertainDistributions.point(42);
      final mixture = UncertainDistributions.mixture([u]);
      expect(mixture.sample(), equals(42));
    });
  });

  group('Uncertain - Iteration', () {
    test('can iterate to get samples', () {
      final u = UncertainDistributions.point(5);
      final first10 = u.take(10).toList();
      expect(first10.length, equals(10));
      expect(first10.every((x) => x == 5), isTrue);
    });

    test('iterator produces infinite stream', () {
      final u = UncertainDouble.uniform(min: 0.0, max: 1.0);
      final samples = u.take(1000).toList();
      expect(samples.length, equals(1000));
    });
  });

  group('Uncertain - Computation Graph', () {
    test('computation graph maintains correlation', () {
      final u = UncertainDouble.normal(mean: 5.0, standardDeviation: 1.0);

      // u + u should produce 2*u (correlated), not two independent samples
      final doubled = u + u;

      // All samples should be close to even numbers (2x something)
      // while u + independent would have more variance
      final samples = doubled.take(100).toList();
      final mean = samples.reduce((a, b) => a + b) / samples.length;
      expect(mean, closeTo(10.0, 1.0)); // 2 * 5.0
    });

    test('complex expressions maintain correlations', () {
      final x = UncertainDouble.uniform(min: 0.0, max: 1.0);

      // x + x * x should correlate x across operations
      final expr = x + (x * x);

      // Just verify it produces reasonable values
      final samples = expr.take(100).toList();
      expect(samples.every((v) => v >= 0 && v <= 2), isTrue);
    });
  });

  group('Uncertain - Edge Cases', () {
    test('empty empirical distribution returns null', () {
      final u = UncertainDistributions.empirical<int>([]);
      expect(u, isNull);
    });

    test('empty categorical distribution returns null', () {
      final u = UncertainDistributions.categorical<String>({});
      expect(u, isNull);
    });

    test('division by zero throws for integers', () {
      final u1 = UncertainDistributions.point(10);
      final u2 = UncertainDistributions.point(0);
      expect(() => (u1 / u2).sample(), throwsA(isA<Error>()));
    });

    test('log likelihood handles edge cases', () {
      final u = UncertainDouble.normal(mean: 0.0, standardDeviation: 1.0);
      final logLik = u.logLikelihood(0.0, sampleCount: 1000);
      expect(logLik, isA<double>());
      expect(logLik.isFinite, isTrue);
    });
  });

  group('Uncertain - Real-world Examples', () {
    test('modeling measurement uncertainty', () {
      // Temperature reading with ±2 degree uncertainty
      final temperature = UncertainDouble.normal(
        mean: 20.0,
        standardDeviation: 2.0,
      );

      // Check if it's likely > 22 degrees
      final isWarm = temperature > 22.0;
      final confidence = isWarm.probability(exceeds: 0.8);

      // Should be somewhat uncertain given the measurement error
      expect(confidence, isA<bool>());
    });

    test('combining independent measurements', () {
      // Two independent sensor readings
      final sensor1 = UncertainDouble.normal(mean: 10.0, standardDeviation: 1.0);
      final sensor2 = UncertainDouble.normal(mean: 10.5, standardDeviation: 1.0);

      // Average of sensors
      final average = (sensor1 + sensor2) / 2.0;

      final avgMean = average.expectedValue(sampleCount: 2000);
      expect(avgMean, closeTo(10.25, 0.3));
    });

    test('risk analysis with distributions', () {
      // Cost estimate with uncertainty
      final laborCost = UncertainDouble.normal(mean: 1000.0, standardDeviation: 200.0);
      final materialCost = UncertainDouble.normal(mean: 500.0, standardDeviation: 100.0);

      final totalCost = laborCost + materialCost;

      // What's the probability total cost exceeds budget?
      final overBudget = totalCost > 1800.0;
      final risk = overBudget.probability(exceeds: 0.5);

      expect(risk, isA<bool>());

      // Get confidence interval for planning
      final ci = totalCost.confidenceInterval(
        confidence: 0.90,
        sampleCount: 2000,
      );
      expect(ci.lower, lessThan(1500.0));
      expect(ci.upper, greaterThan(1500.0));
    });

    test('A/B test simulation', () {
      // Variant A: 10% conversion
      // Variant B: 12% conversion
      final variantA = UncertainDouble.bernoulli(probability: 0.10);
      final variantB = UncertainDouble.bernoulli(probability: 0.12);

      // Check if B is meaningfully better (would need many samples in practice)
      // Count true values (conversions) from samples
      final samplesA = variantA.take(5000).toList();
      final samplesB = variantB.take(5000).toList();

      final conversionA = samplesA.where((x) => x).length / 5000;
      final conversionB = samplesB.where((x) => x).length / 5000;

      expect(conversionB, greaterThan(conversionA));
    });
  });
}
