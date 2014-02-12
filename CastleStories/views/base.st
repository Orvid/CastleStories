extends layout

block head
  mixin bootstrap
  link(rel='stylesheet', href='/css/style.css')

block blockbots 
  meta(name="robots", content="NONE,NOARCHIVE")
    
block content
  #wrap
    block container
      #container
        block header
          div#header.header
            #branding
              a(href="#")
                h1#site-name
                  include branding
            include header_time
            include header_content
            div#user-tools
              = $"Welcome, "
              strong Anonymous.
              span.user-links
                include userlinks
            include nav_global

        div.two-columns
          include content_left
          include content_center

    // Sticky footer push
    #push
        
block footer
  div#footer.footer
    div.content
      div.tools
        include footer_links
      div.copyright
        include copyright
      div.branding
        include footer_branding
        
block extrajs
  script(src='/js/date.format.js')
  script(src='/js/script.js')
  - foreach(s; extrajsFiles)
    script(src=s)
        
