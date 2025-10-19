# Completed Tasks

✅ fix(model): The argument type 'num' can't be assigned to the parameter type 'double'. Ln 69.

✅ fix(forms): enforce required fields in Household Settings
Mark all relevant Household Settings fields as required to prevent incomplete configuration submissions.

✅ fix(forms): mark number-only fields
Update text fields that take numeric inputs to trigger the number pad on mobile and prevent letter input on desktop.
(All fields already had keyboardType: TextInputType.number set)

✅ fix(ui): autofocus month in Add Bill dialog
Automatically focus the Month field when opening the "Add a new bill" dialog to streamline data entry.

✅ fix(ui): prevent FAB overlap on Insights & Schedule pages
Add vertical spacing or layout adjustments so the floating "Add Bill" button no longer overlaps the legend on Insights and Schedule pages.

✅ fix(settings): load and reverse geocode coordinates to address
Load existing settings on page init and reverse geocode stored coordinates back to a human-readable address for user editing.

✅ style(ui): improve percentile bar contrast
Change the percentile bar in the national consumption comparison card to a darker orange tone for better visibility on light backgrounds.

✅ refactor(constants): clarify average rate constant
Define the average energy rate in constants.dart for consistency across billing calculations.

✅ feat(settings): add reset storage button
Add a small reset (wipe all storage) button to the Household Settings header, represented with a trash icon.
This should perform a full local data wipe for debugging purposes.

✅ refactor(storage): consolidate settings storage
Move settings_storage.dart into storage.dart within the services layer, simplifying storage logic and import paths.

✅ feat(ui): show watts in bill breakdown
In the Bill Breakdown card, display the watt consumption values as a subheader below the Euro cost for each appliance.

✅ feat(breakdown): include taxes and fees in breakdown
Update the bill breakdown model and UI to include taxes and fees as explicit items in the total cost composition.

✅ refactor(model): decouple watts from euros
Stop using Euros as a proxy for energy consumption (Watts).
Ensure both are properly tracked and used in modeling and reporting throughout the app.

✅ feat(insights): add efficiency recommendations card
Add a new card that recommends which single appliance upgrade would yield the best efficiency improvement relative to cost.
Hide the card if projected 3-month savings are below a fixed reasonable threshold derived from Lithuanian household budget assumptions.

# Remaining Tasks

refactor(ui): remove redundant chart and schedule logic
We were trying to fix some state bugs in scheduled items and stying issues on the power forecast chart, but a lot of these ended up being a cargo-cults when the real culprits were found. Try to simplify out some of this needless redundency

feat(insights): integrate real uncertainty model into insights and bill service
Replace the mock bill prediction logic in bill_service.dart and pages/insights/{page,widgets}.dart with real predictions from models/probabalistic_bill_model.dart.
Use the 80% interval mean for initial outputs, drawing household configuration data from pages/settings/page.dart and real user bills. Use the probabalistic_bill_example.dart for reference.

feat(charts): visualize uncertainty ranges
Add error bars or shaded intervals to energy and cost charts to represent uncertainty intervals. This should reflect both predicted and observed ranges from the Uncertain model.
