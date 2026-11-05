// The looks the wrapper knows. theme.conf [HyprThemes] Looks= says which of them this install was built with.
//   dir            subdirectory holding the look's Main.qml
//   configSection  section of theme.conf that holds its config; "" = the top level (only for a look that reads config from a singleton)
//   session        the session file picking this look selects
//   desktop        what that session logs into, for the menu
.pragma library

var all = [
    { id: "waguri",     label: "Waguri",     dir: "looks/silent",     configSection: "",                session: "hyprland-stock.desktop",      desktop: "stock Hyprland" },
    { id: "overworld",  label: "Overworld",  dir: "looks/overworld",  configSection: "look.overworld",  session: "hyprland-overworld.desktop",  desktop: "Hyprland · Overworld" },
    { id: "apothecary", label: "Apothecary", dir: "looks/apothecary", configSection: "look.apothecary", session: "hyprland-apothecary.desktop", desktop: "Hyprland · Apothecary" }
];
