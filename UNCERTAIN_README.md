# Uncertain - Dart Implementation

A Dart port of the [Uncertain<T> Swift library](https://github.com/mattt/Uncertain) for working with probability distributions using type-based abstractions.

## Overview

`Uncertain` provides a way to work with probabilistic values by representing them as sampling functions with a computation graph for lazy evaluation and proper uncertainty-aware conditionals.

This implementation follows the approach described in:

> James Bornholt, Todd Mytkowicz, and Kathryn S. McKinley.
> "Uncertain<T>: A First-Order Type for Uncertain Data."
> ASPLOS, March 2014.
> https://www.microsoft.com/en-us/research/publication/uncertaint-a-first-order-type-for-uncertain-data-2/

## Features

- **Type-safe probabilistic values** - Generic `Uncertain<T>` type for any data
- **Rich set of distributions**:
  - Continuous: Normal, Uniform, Exponential, Kumaraswamy, Rayleigh
  - Discrete: Binomial, Poisson, Bernoulli
  - Categorical and Empirical distributions
  - Mixture distributions with custom weights
- **Arithmetic operators** - Add, subtract, multiply, divide uncertain values
- **Comparison operators** - Compare with thresholds to get evidence
- **Boolean logic** - AND, OR, NOT operations on uncertain booleans
- **SPRT-based conditionals** - Sequential Probability Ratio Test for hypothesis testing
- **Computation graphs** - Maintains correlations across operations
- **Statistical methods**:
  - Expected value, standard deviation, variance
  - Skewness, kurtosis
  - Mode, median, quantiles
  - Confidence intervals, CDF
  - Entropy, histograms
- **Transformations** - map, flatMap, filter with rejection sampling

## Quick Start

```dart
import 'package:powertime/uncertain.dart';

// Create a normal distribution
final temperature = UncertainDouble.normal(mean: 20.0, standardDeviation: 2.0);

// Hypothesis testing with SPRT
final isWarm = temperature > 22.0;
if (isWarm.probability(exceeds: 0.9)) {
  print("90% confident it's warm");
}

// Implicit conditional (50% threshold)
if (isWarm.implicitConditional()) {
  print("More likely than not it's warm");
}

// Arithmetic operations
final cost1 = UncertainDouble.normal(mean: 100.0, standardDeviation: 10.0);
final cost2 = UncertainDouble.normal(mean: 150.0, standardDeviation: 15.0);
final total = cost1 + cost2;

print('Expected total: ${total.expectedValue()}');
print('95% CI: ${total.confidenceInterval(confidence: 0.95)}');
```

## Distribution Examples

### Continuous Distributions

```dart
// Normal (Gaussian)
final heights = UncertainDouble.normal(mean: 170.0, standardDeviation: 10.0);

// Uniform
final random = UncertainDouble.uniform(min: 0.0, max: 100.0);

// Exponential
final waitTime = UncertainDouble.exponential(rate: 0.5);

// Kumaraswamy (bounded to [0, 1])
final proportion = UncertainDouble.kumaraswamy(a: 2.0, b: 5.0);

// Rayleigh
final distance = UncertainDouble.rayleigh(scale: 1.0);
```

### Discrete Distributions

```dart
// Binomial
final successes = UncertainInt.binomial(trials: 100, probability: 0.3);

// Poisson
final events = UncertainInt.poisson(lambda: 5.0);

// Bernoulli
final coinFlip = UncertainDouble.bernoulli(probability: 0.5);
```

### Categorical and Empirical

```dart
// Categorical
final diceRoll = UncertainDistributions.categorical({
  1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0,
})!;

// Empirical (from observed data)
final data = [1.2, 3.4, 2.1, 5.6, 4.3];
final empirical = UncertainDistributions.empirical(data)!;

// Point mass (deterministic)
final certain = UncertainDistributions.point(42);
```

### Mixture Distributions

```dart
final peak = UncertainDouble.normal(mean: 100.0, standardDeviation: 5.0);
final offPeak = UncertainDouble.normal(mean: 50.0, standardDeviation: 10.0);

final demand = UncertainDistributions.mixture(
  [peak, offPeak],
  weights: [0.3, 0.7], // 30% peak hours, 70% off-peak
);
```

## Operations

### Arithmetic

```dart
final x = UncertainDouble.normal(mean: 5.0, standardDeviation: 1.0);
final y = UncertainDouble.normal(mean: 3.0, standardDeviation: 0.5);

final sum = x + y;
final diff = x - y;
final product = x * y;
final quotient = x / y;
final negation = -x;

// Works with constants too
final scaled = x * 2.0;
final shifted = x + 10.0;
```

### Comparisons

```dart
final value = UncertainDouble.normal(mean: 50.0, standardDeviation: 10.0);

// Returns Uncertain<bool> evidence
final evidence1 = value > 45.0;
final evidence2 = value < 60.0;
final evidence3 = value >= 40.0;
final evidence4 = value <= 70.0;
final evidence5 = value.eq(50.0);
final evidence6 = value.neq(0.0);
```

### Boolean Logic

```dart
final a = UncertainDouble.bernoulli(probability: 0.7);
final b = UncertainDouble.bernoulli(probability: 0.5);

final notA = ~a;
final both = a.and(b);
final either = a.or(b);
```

### Transformations

```dart
// Map: transform samples
final celsius = UncertainDouble.normal(mean: 20.0, standardDeviation: 2.0);
final fahrenheit = celsius.map((c) => c * 9 / 5 + 32);

// FlatMap: chain uncertain operations
final x = UncertainDouble.uniform(min: 0.0, max: 1.0);
final conditional = x.flatMap((val) =>
  val > 0.5
    ? UncertainDouble.normal(mean: 10.0, standardDeviation: 1.0)
    : UncertainDouble.normal(mean: 5.0, standardDeviation: 0.5)
);

// Filter: rejection sampling
final positiveOnly = UncertainDouble.normal(mean: 0.0, standardDeviation: 1.0)
    .filter((x) => x > 0);
```

## Statistical Methods

```dart
final data = UncertainDouble.normal(mean: 100.0, standardDeviation: 15.0);

// Central tendency
final mean = data.expectedValue(sampleCount: 2000);
final median = data.median(sampleCount: 2000);
final mode = data.mode(sampleCount: 2000);

// Spread
final std = data.standardDeviation(sampleCount: 2000);
final ci = data.confidenceInterval(confidence: 0.95, sampleCount: 2000);

// Shape
final skew = data.skewness(sampleCount: 2000);
final kurt = data.kurtosis(sampleCount: 2000);

// Distribution
final cdf50 = data.cdf(value: 100.0, sampleCount: 2000);
final q25 = data.quantile(quantile: 0.25, sampleCount: 2000);

// Information
final entropy = data.entropy(sampleCount: 2000);
final histogram = data.histogram(sampleCount: 2000);
```

## Hypothesis Testing with SPRT

The library uses Sequential Probability Ratio Test for efficient hypothesis testing:

```dart
final measurement = UncertainDouble.normal(mean: 5.0, standardDeviation: 1.0);
final isHigh = measurement > 6.0;

// Test with 90% confidence
if (isHigh.probability(exceeds: 0.9)) {
  print("Strong evidence that measurement > 6.0");
}

// Custom error rates
if (isHigh.probability(
  exceeds: 0.95,
  alpha: 0.01,    // Type I error rate
  beta: 0.01,     // Type II error rate
  maxSamples: 5000,
)) {
  print("Very strong evidence with strict error control");
}

// Implicit conditional (50% threshold)
if (isHigh.implicitConditional()) {
  print("More likely than not > 6.0");
}
```

## Computation Graphs

The library maintains computation graphs to preserve correlations:

```dart
final x = UncertainDouble.uniform(min: 0.0, max: 1.0);

// x + x is correlated (produces 2*x)
final doubled = x + x;
print('E[x + x] = ${doubled.expectedValue()}'); // ≈ 1.0

// x + independent_x is not correlated
final x2 = UncertainDouble.uniform(min: 0.0, max: 1.0);
final independent = x + x2;
print('E[x + x\'] = ${independent.expectedValue()}'); // ≈ 1.0

// But variance differs!
print('Var[x + x] = ${doubled.standardDeviation()}²');     // ≈ (0.577)²
print('Var[x + x\'] = ${independent.standardDeviation()}²'); // ≈ (0.408)²
```

## Real-World Example: Risk Analysis

```dart
// Project cost estimation with uncertainty
final laborCost = UncertainDouble.normal(
  mean: 50000.0,
  standardDeviation: 5000.0,
);

final materialCost = UncertainDouble.normal(
  mean: 30000.0,
  standardDeviation: 3000.0,
);

final overhead = UncertainDistributions.point(10000.0);

final totalCost = laborCost + materialCost + overhead;
final budget = 100000.0;

// Risk assessment
final overBudget = totalCost > budget;
final highRisk = overBudget.probability(exceeds: 0.5);

print('Expected cost: \$${totalCost.expectedValue()}');
print('Budget: \$${budget}');
print('Over budget risk: ${highRisk ? "HIGH" : "LOW"}');

// Planning with confidence intervals
final ci = totalCost.confidenceInterval(
  confidence: 0.90,
  sampleCount: 2000,
);
print('90% confident cost in [\$${ci.lower}, \$${ci.upper}]');

// Calculate buffer needed for 95% success probability
final q95 = totalCost.quantile(quantile: 0.95, sampleCount: 2000);
print('Recommended budget for 95% success: \$${q95}');
```

## Sampling

You can iterate directly over an uncertain value to get samples:

```dart
final dist = UncertainDouble.normal(mean: 0.0, standardDeviation: 1.0);

// Take finite samples
final samples = dist.take(1000).toList();

// Process samples
final mean = samples.reduce((a, b) => a + b) / samples.length;

// Sample manually
final singleSample = dist.sample();
```

## Testing

Run the comprehensive test suite:

```bash
flutter test test/uncertain_test.dart
```

The test suite includes 59 tests covering:
- Basic construction and distributions
- Operators and transformations
- Boolean logic and conditionals
- Statistical methods
- Computation graphs
- Edge cases
- Real-world examples

## Differences from Swift Version

This Dart implementation is faithful to the Swift original with these adjustments for Dart's type system:

1. **No intersection types**: Dart doesn't support `T extends num & Comparable<T>`, so we use separate type constraints
2. **No prefix operators**: Dart doesn't allow custom prefix operators like `~`, so we use `.implicitConditional()` method
3. **Named constructors**: Uses Dart's extension system for distribution factory methods
4. **Records**: Uses Dart 3.0 records for returning tuples (e.g., confidence intervals)
5. **No @Sendable**: Dart handles concurrency differently, so threading annotations aren't needed

## Performance

- SPRT provides adaptive sampling - uses only as many samples as needed for statistical significance
- Computation graphs enable efficient correlated sampling
- Lazy evaluation defers computation until needed
- Sample caching avoids redundant calculations within a single evaluation

## License

This is a port of the original Swift Uncertain library. See the [original repository](https://github.com/mattt/Uncertain) for license information.

## References

- [Original Swift Implementation](https://github.com/mattt/Uncertain)
- [Uncertain<T> Paper (ASPLOS 2014)](https://www.microsoft.com/en-us/research/publication/uncertaint-a-first-order-type-for-uncertain-data-2/)
- [Sequential Probability Ratio Test](https://en.wikipedia.org/wiki/Sequential_probability_ratio_test)
