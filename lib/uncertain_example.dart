import 'uncertain.dart';

/// Example usage of the Uncertain library
void main() {
  // Example 1: Simple probability distributions
  print('=== Example 1: Normal Distribution ===');
  final temperature = UncertainDouble.normal(mean: 20.0, standardDeviation: 2.0);

  print('Expected temperature: ${temperature.expectedValue(sampleCount: 1000).toStringAsFixed(2)}°C');
  print('Std deviation: ${temperature.standardDeviation(sampleCount: 1000).toStringAsFixed(2)}°C');

  final ci = temperature.confidenceInterval(confidence: 0.95, sampleCount: 1000);
  print('95% CI: [${ci.lower.toStringAsFixed(2)}, ${ci.upper.toStringAsFixed(2)}]');

  // Example 2: Probability conditionals with SPRT
  print('\n=== Example 2: Hypothesis Testing ===');
  final speed = UncertainDouble.normal(mean: 5.0, standardDeviation: 2.0);

  final isFast = speed > 4.0;
  if (isFast.probability(exceeds: 0.9)) {
    print('90% confident speed > 4.0');
  } else {
    print('Less than 90% confident speed > 4.0');
  }

  // Implicit conditional (50% threshold)
  if (isFast.implicitConditional()) {
    print('More likely than not: speed > 4.0');
  }

  // Example 3: Combining distributions
  print('\n=== Example 3: Arithmetic with Uncertain Values ===');
  final cost1 = UncertainDouble.normal(mean: 100.0, standardDeviation: 10.0);
  final cost2 = UncertainDouble.normal(mean: 150.0, standardDeviation: 15.0);

  final totalCost = cost1 + cost2;
  print('Total cost: ${totalCost.expectedValue(sampleCount: 2000).toStringAsFixed(2)}');

  final profit = cost1 * 1.2 - cost2;
  print('Profit: ${profit.expectedValue(sampleCount: 2000).toStringAsFixed(2)}');

  // Example 4: Discrete distributions
  print('\n=== Example 4: Discrete Distributions ===');
  final diceRoll = UncertainDistributions.categorical({
    1: 1.0,
    2: 1.0,
    3: 1.0,
    4: 1.0,
    5: 1.0,
    6: 1.0,
  })!;

  print('Most common roll: ${diceRoll.mode(sampleCount: 6000)}');
  print('Average roll: ${diceRoll.expectedValue(sampleCount: 6000).toStringAsFixed(2)}');

  // Example 5: Binomial distribution (coin flips)
  print('\n=== Example 5: Binomial Distribution ===');
  final coinFlips = UncertainInt.binomial(trials: 100, probability: 0.5);
  print('Expected heads: ${coinFlips.expectedValue(sampleCount: 1000).toStringAsFixed(1)}');

  // Example 6: Filtering with rejection sampling
  print('\n=== Example 6: Rejection Sampling ===');
  final positive = UncertainDouble.normal(mean: 0.0, standardDeviation: 1.0)
      .filter((x) => x > 0);

  print('Expected value (positive only): ${positive.expectedValue(sampleCount: 2000).toStringAsFixed(2)}');

  // Example 7: Computation graph maintains correlation
  print('\n=== Example 7: Computation Graph ===');
  final x = UncertainDouble.uniform(min: 0.0, max: 1.0);

  // x + x should be 2x (correlated)
  final doubled = x + x;
  print('E[x + x] = ${doubled.expectedValue(sampleCount: 2000).toStringAsFixed(3)}');

  // This is different from x + independent_x
  final x2 = UncertainDouble.uniform(min: 0.0, max: 1.0);
  final independent = x + x2;
  print('E[x + x\'] = ${independent.expectedValue(sampleCount: 2000).toStringAsFixed(3)}');

  // Example 8: Mixture distributions
  print('\n=== Example 8: Mixture Distribution ===');
  final peak = UncertainDouble.normal(mean: 100.0, standardDeviation: 5.0);
  final offPeak = UncertainDouble.normal(mean: 50.0, standardDeviation: 10.0);

  final demand = UncertainDistributions.mixture(
    [peak, offPeak],
    weights: [0.3, 0.7], // 30% peak, 70% off-peak
  );

  print('Expected demand: ${demand.expectedValue(sampleCount: 2000).toStringAsFixed(2)}');

  // Example 9: Statistical properties
  print('\n=== Example 9: Statistical Properties ===');
  final data = UncertainDouble.exponential(rate: 0.5);

  print('Mean: ${data.expectedValue(sampleCount: 2000).toStringAsFixed(2)}');
  print('Std: ${data.standardDeviation(sampleCount: 2000).toStringAsFixed(2)}');
  print('Skewness: ${data.skewness(sampleCount: 2000).toStringAsFixed(2)}');
  print('Kurtosis: ${data.kurtosis(sampleCount: 2000).toStringAsFixed(2)}');

  // Example 10: Quantiles
  print('\n=== Example 10: Quantiles ===');
  final heights = UncertainDouble.normal(mean: 170.0, standardDeviation: 10.0);

  print('25th percentile: ${heights.quantile(quantile: 0.25, sampleCount: 2000).toStringAsFixed(2)} cm');
  print('Median: ${heights.median(sampleCount: 2000).toStringAsFixed(2)} cm');
  print('75th percentile: ${heights.quantile(quantile: 0.75, sampleCount: 2000).toStringAsFixed(2)} cm');

  // Example 11: Sampling directly
  print('\n=== Example 11: Direct Sampling ===');
  final samples = UncertainDouble.uniform(min: 0.0, max: 100.0);
  print('First 5 samples: ${samples.take(5).map((x) => x.toStringAsFixed(1)).join(", ")}');

  // Example 12: Real-world - Risk analysis
  print('\n=== Example 12: Risk Analysis ===');
  final laborCost = UncertainDouble.normal(mean: 50000.0, standardDeviation: 5000.0);
  final materialCost = UncertainDouble.normal(mean: 30000.0, standardDeviation: 3000.0);
  final overhead = UncertainDistributions.point(10000.0);

  final projectCost = laborCost + materialCost + overhead;
  final budget = 100000.0;

  final overBudget = projectCost > budget;
  final risk = overBudget.probability(exceeds: 0.5);

  print('Expected project cost: \$${projectCost.expectedValue(sampleCount: 2000).toStringAsFixed(2)}');
  print('Budget: \$${budget.toStringAsFixed(2)}');
  print('Over budget risk: ${risk ? "HIGH" : "LOW"}');

  final costCI = projectCost.confidenceInterval(confidence: 0.90, sampleCount: 2000);
  print('90% CI: [\$${costCI.lower.toStringAsFixed(2)}, \$${costCI.upper.toStringAsFixed(2)}]');
}
