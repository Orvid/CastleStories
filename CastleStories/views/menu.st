template menuItem(menuName, defaultPath, iconClass, itemTitle, children?)
  - static if (menu == menuName)
    - enum menuClass = "active";
  - else
    - enum menuClass = "";
  li(class=menuClass)
    a(href=defaultPath)
      i(class=iconClass)
      = $(itemTitle)
    static if __traits(compiles, typeof(children))
      ul
        include children

template submenuItem(submenuName, targetPath, itemTitle)
  - static if (submenu == submenuName)
    - enum submenuClass = "active";
  - else
    - enum submenuClass = "";
  li(class=submenuClass)
    a(href=targetPath)= $(itemTitle)

div#left-nav.left-nav
  ul
    include menuItem("home", "/", "icon-home", "Home")
    include menuItem("realtime", "/realtime/overview", "icon-repeat", "Real-Time", menu_realtime)
    template menu_realtime()
      include submenuItem("overview", "/realtime/overview", "Overview")
    include menuItem("users", "/users/players", "icon-user", "Users", menu_users)
    template menu_users()
      include submenuItem("players", "/users/players", "Active Players")
      include submenuItem("observers", "/users/observers", "Observers")
    include menuItem("sessions", "/sessions/current", "icon-eye-open", "Sessions", menu_sessions)
    template menu_sessions()
      include submenuItem("current", "/sessions/current", "Current")
      include submenuItem("persistent", "/sessions/persistent", "Persistent")
      include submenuItem("recorded", "/sessions/recorded", "Recorded")
    include menuItem("maps", "/maps", "icon-map-marker", "Maps")
    include menuItem("entities", "/entities/spawned", "icon-th", "Entities", menu_entities)
    template menu_entities()
      include submenuItem("spawned", "/entities/spawned", "Spawned")
      include submenuItem("blocks", "/entities/blocks", "Blocks")
    include menuItem("settings", "/settings/games", "icon-cog", "Settings", menu_settings)
    template menu_settings()
      include submenuItem("games", "/settings/games", "Games")
      include submenuItem("server", "/settings/server", "Server")
    include menuItem("auth", "/auth/admins", "icon-lock", "Authentication", menu_auth)
    template menu_auth()
      include submenuItem("admins", "/auth/admins", "Admins")
      include submenuItem("server", "/auth/server", "Server")