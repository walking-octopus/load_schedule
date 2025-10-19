feat(breakdown): include taxes and fees in breakdown
Update the bill breakdown model and UI to include taxes and fees as explicit items in the total cost composition.

refactor(ui): remove redundant chart and schedule logic
We were trying to fix some state bugs in scheduled items and stying issues on the power forecast chart, but a lot of these ended up being a cargo-cults when the real culprits were found. Try to simplify out some of this needless redundency.

feat(insights): integrate real uncertainty model into insights and bill service
Replace the mock bill prediction logic in bill_service.dart and pages/insights/{page,widgets}.dart with real predictions from models/probabalistic_bill_model.dart.
Use the 80% interval mean for initial outputs, drawing household configuration data from pages/settings/page.dart and real user bills. Use the probabalistic_bill_example.dart for reference.

feat(charts): visualize uncertainty ranges
Add error bars or shaded intervals to energy and cost charts to represent uncertainty intervals. This should reflect both predicted and observed ranges from the Uncertain model.
