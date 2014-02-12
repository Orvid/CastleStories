!!! 5
html
  head
    title= title
    include head
    include extrahead
    include blockbots
  body.dashboard
    include content
    include footer
    script(src='/js/bootstrap.min.js') 
    include extrajs