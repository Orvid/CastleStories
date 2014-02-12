$(function () {
  $(document).ready(function() {
    var updateTime = function(now) {
      $('#date').html(now.format("dddd, mmmm dS yyyy"));
      $('#clock').html(now.format("h:MM:ss TT"));
    };
    
    var now = new Date();
    updateTime(now);
    
    setInterval( function() 
    {
        var now = new Date();
        updateTime(now);
    }, 1000);
  })
});