- Add BottomBar {
    NavItem {icon: calendar, "Schedule", page: homePage }
    NavItem { icon: eye, "Insights", page: insightsPage }
}

- Add Page {
    id: insights

    AppBar {
        label: "Insights"
        NavItem { icon: gear, page: settingsPage }
    }

    Placeholder {
        icon: house
        title: "No settings found"
        subtitle: "Press the gear button to configure your household
    }

    Label { role: header-large, "Bill Breakdown"  }

    Horizontal {
        Vertical {
            Label { role: subheader, "${lastBill.total} EUR (as char)" }
            StackChart { data: applianceFraction }
        }
        ComponentItem {
            // each label aligned with load stack's fraciton

            Label {role: subheader, label: "Heating" }
            Label {role: subheader, label: "450 EURO \dot 3 kWh" }
            ...
        }
    }

    Label { role: header-large, "Consumption"  }
        Graph {
            Src {
                src: monthly-consumption
                style: normal
            }
            Src {
                src: predicted
                style: dotted
            }

            Legend { ... }
        }

    FloatingButton {
        icon: add
        label: "Add bill"

        opens: Dialog {
            title: Add a new bill

            DateSelector { overtext: "Bill Month/Year" }
            Input { type: num, overtext: "Bill paid" }
        }
    }
}

- Add a Page for household settings, it should be a well-presented progressively disclosed vertical form organized like this:

<- Household Settings

Section Header: "Your Home"

TextInput: "Address" with LocateButton
NumInput: "Area (m^2)"
SpinBox{ overtext: "Occupants", min: 1 }
ChipSelector { overtext: "Building type", ["Appartment" "Detached"] }
NumInput { overtext: Construction Year }

Section Header: "Appliance efficiency"

ListModal {
    Vertical { Overtext "Microwave" } ChipSelector {["Poor", "Medium", "Good", "Excellent"] }
    ...
} for []

Section Header: "Electric vehicles"

{ overtext: "Do you have an electric vehicle?",
  ChipSelect: ["Yes", "No" }

If EV {
    NumInput{ overtext: "Daily km" }
    NumInput{ "Battery Capacity" }
}

- Add a service for weather (temperature and daylight hours (lights))

- Use basic uncertainty propagation to calculate expected bills and breakdowns based on that data