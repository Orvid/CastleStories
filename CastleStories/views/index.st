extends base
  
block branding
  p= title

block header_time
  div.header-content.header-content-first
    div.header-column.icon
      i.icon-time
    div.header-column
      span#date.date  
      br
      span#clock.time 

block userlinks
  a(href="#")= $Documentation
  span.separator |
  a(href="#")= $"Change password"
  span.separator | 
  a(href="#")= $"Sign out"

block content_left
  div.left-column
    block quick_search
      form.form-search.nav-quick-search(autocomplete="off", action="/", method="GET")
        input#quick-search.input-medium.search-query(type="text", name="q")
        i.input-icon.icon-search
        input.submit(type="submit",value="")
    mixin menu

block content_center
  div.center-column.clearfix
    block breadcrumbs
      ul.breadcrumb
        li
          a(href="#")= $"Real-Time"
          span.divider= "»"
        li.active
          a(href="#")= $Overview
    include messages
    // Content
    div#content.colM
      block pretitle
        block content_title
          h2.content-title= $Title
      include content_core
      include sidebar
      br.clearfix
    // END Content

block copyright
  span Copyright &copy; 2013 Sauropod Studio, Inc
    br
    = $"Developed by"
  a(href="http://sauropodstudio.com", target="_blank") SauropodStudio.com 

block footer_branding
  span #{versionInfo}

block footer_links
  a.icon(href="http://support.castlestory.net/", target="_blank")
    i.icon-question-sign
    = $Support
  a.icon(href="http://sauropodstudio.com/", target="_blank")
    i.icon-bookmark
    = $License
  a.icon(href="http://github.com/Sauropod-Studio/castlestory-server/issues", target="_blank")
    i.icon-comment
    = $"Report a bug"

