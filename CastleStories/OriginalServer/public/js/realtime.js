var socket = io.connect("/analytics");
var messages = {};
var lastMessageId = 0;
var messagesReceived = 0;
var lastConnections = 0;
var latencyValues = {};
var latencyFunc = null;

socket.on('connect', function () {
    socket.on('messages', function (msg) {
        messagesReceived++;
        if (msg.connections > 0 && msg.connections != lastConnections) {
          if (msg.connections+1 == 1) {
            $('#connections-singular').css('display', 'block');
            $('#connections-plural').css('display', 'none');
          } else {
            $('#connections-singular').css('display', 'none');
            $('#connections-plural').css('display', 'block');            
          }
          $('#connections').html(msg.connections+1);
          $('#players').css('display', 'inline');
          $('#players').html(msg.connections);
          $('#players-label').css('display', 'inline');
          // calculate %
          var connections = parseFloat(msg.connections)+1.0;
          var players_percent =  Math.round((parseFloat(msg.connections) / connections)*100);
          var observers_percent = Math.round((1.0 / connections)*100);
          $('#players-percent').html(String(players_percent) + '%');
          $('#players-percent').css('width', String(players_percent) + '%');
          $('#players-percent').css('display', 'inline');
          $('#observers-percent').html(String(observers_percent) + '%');
          $('#observers-percent').css('width', String(observers_percent) + '%');
          lastConnections = msg.connections;
        } else if (msg.connections == 0) {
          $('#connections').html('1');
          $('#players').css('display', 'none')
          $('#players').html('0');
          $('#players-label').css('display', 'none');
          $('#players-percent').css('display', 'none'); 
          $('#observers-percent').html('100%');
          $('#observers-percent').css('width', '100%');
          $('#connections-singular').css('display', 'block');
          $('#connections-plural').css('display', 'none');
          lastConnections = 0;
        }
        if (msg.action) {
            if ($('#messages tr').length > 10) {
                $('#messages tr:last').remove();
            }
			msg.latency = Math.abs(Math.round(((parseFloat(msg.timestamp)-parseFloat(msg.msg[1]))*1000)));
            $('#messages tbody').prepend('<tr><td>' + msg.from + '</td><td>' + msg.action + '</td><td>' + msg.msg + '</td><td>' + msg.timestamp + '</td><td>' + msg.latency + '</td></tr>');

			if (latencyFunc != null && msg.latency < 10000){
				latencyFunc(msg);
			}
            if (messages[msg.action]) {
                messages[msg.action].received = messages[msg.action].received + 1;
                $('#message' + messages[msg.action].messageId).html(messages[msg.action].received);
            } else {
                messages[msg.action] = {received: 1, messageId: ++lastMessageId};
                $('#message tbody').append('<tr><td>' + msg.action + '</td><td id="message' + lastMessageId + '">1</td></tr>');
            }
        }
    });

});

$(function () {
    $(document).ready(function() {
        Highcharts.setOptions({
            global: {
                useUTC: false
            }
        });
    
        var chart;
        var messagesReceivedPerMinute = 0;
        chart = new Highcharts.Chart({
            chart: {
                renderTo: 'graph-per-minute',
                type: 'column',

                // Edit chart spacing
                spacingBottom: 0,
                spacingTop: 0,
                spacingLeft: 0,
                spacingRight: 0,

                // Explicitly tell the width and height of a chart
                width: null,
                height: 200,
                backgroundColor: '#f5f5f5',
                style: {
                    fontFamily: '"Helvetica Neue", Helvetica, Arial, sans-serif', 
                    fontSize: '14px',
                },
                events: {
                    load: function() {
    
                        // set up the updating of the chart each second
                        var series = this.series[0];
                        setInterval(function() {
                            var x = (new Date()).getTime(), // current time
                                y = messagesReceived - messagesReceivedPerMinute; //Math.floor(Math.random()*20);
                            messagesReceivedPerMinute = messagesReceived;
                            series.addPoint([x, y], true, true);
                        }, 60000);
                    }
                },
                credits: {
                  enabled: false
                },
            },
            title: {
                align: 'left',
                text: 'Per minute',
                style: {
                    color: '#555555',
                    fontFamily: '"Helvetica Neue", Helvetica, Arial, sans-serif', 
                    fontSize: '14px',
                }
            },
            xAxis: {
                labels: {
                    enabled: false
                },
                type: 'datetime',
                //tickPixelInterval: 25
                tickInterval: 5 * 60 * 1000
            },
            yAxis: {
                labels: {
                  x: 14,
                  y: 10,
                  color: '#808080',
                  style: {
                      fontSize: '9px'                  
                  }
                },
                title: {
                    enabled : false
                },
                plotLines: [{
                    value: 0,
                    width: 1,
                    color: '#cccccc'
                }]
            },
            plotOptions: {
              column: {
                pointWidth: 5,
                borderWidth: 0,
                color: 'rgba(75,177,207,0.5)'
              }
            },
            tooltip: {
                //enabled: false,
                formatter: function() {
                        return '<b>'+ Highcharts.dateFormat("%H:%M", this.x, false) + '</b><br>' + 'Messages: ' + '<b>' + 
                        Highcharts.numberFormat(this.y, 0) + '</b>';
                }
            }, 
            legend: {
                enabled: false
            },
            exporting: {
                enabled: false
            },
            series: [{
                name: 'Random data',
                pointInterval: 5 * 60 * 1000,
                data: (function() {
                    // generate an array of random data
                    var data = [],
                        time = (new Date()).getTime(),
                        i;
    
                    for (i = -29; i <= 0; i++) {
                        data.push({
                            x: time + i * 60000,
                            y: 0
                        });
                    }
                    return data;
                })()
            }]
        });
    });
});

$(function () {
    $(document).ready(function() {
        Highcharts.setOptions({
            global: {
                useUTC: false
            }
        });
    
        var chart;
        var messagesReceivedPerSecond = 0;
        chart = new Highcharts.Chart({
            chart: {
                renderTo: 'graph-per-second',
                type: 'column',

                // Edit chart spacing
                spacingBottom: 0,
                spacingTop: 0,
                spacingLeft: 0,
                spacingRight: 0,

                // Explicitly tell the width and height of a chart
                width: null,
                height: 200,
                backgroundColor: '#f5f5f5',
                style: {
                    fontFamily: '"Helvetica Neue", Helvetica, Arial, sans-serif', 
                    fontSize: '14px',
                },
                events: {
                    load: function() {
    
                        // set up the updating of the chart each second
                        var series = this.series[0];
                        setInterval(function() {
                            var x = (new Date()).getTime(), // current time
                                y = messagesReceived - messagesReceivedPerSecond; //Math.floor(Math.random()*20);
                            messagesReceivedPerSecond = messagesReceived;
                            series.addPoint([x, y], true, true);
                        }, 1000);
                    }
                },
                credits: {
                  enabled: false
                },
            },
            title: {
                align: 'left',
                text: 'Per second',
                style: {
                    color: '#555555',
                    fontFamily: '"Helvetica Neue", Helvetica, Arial, sans-serif', 
                    fontSize: '14px',
                }
            },
            xAxis: {
                labels: {
                    enabled: false
                },
                type: 'datetime',
                tickPixelInterval: 150
            },
            yAxis: {
                labels: {
                  x: 14,
                  y: 10,
                  color: '#808080',
                  style: {
                      fontSize: '9px'                  
                  }
                },
                title: {
                    enabled : false
                },
                plotLines: [{
                    value: 0,
                    width: 1,
                    color: '#cccccc'
                }]
            },
            plotOptions: {
              column: {
                pointWidth: 5,
                borderWidth: 0,
                color: 'rgb(58, 135, 173)'
              }
            },
            tooltip: {
                //enabled: false,
                formatter: function() {
                        return '<b>'+ Highcharts.dateFormat("%H:%M:%S", this.x, false) + '</b><br>' + 'Messages: ' + '<b>'+
                        Highcharts.numberFormat(this.y, 0) + '</b>';
                }
            }, 
            legend: {
                enabled: false
            },
            exporting: {
                enabled: false
            },
            series: [{
                name: 'Random data',
                data: (function() {
                    // generate an array of random data
                    var data = [],
                        time = (new Date()).getTime(),
                        i;
    
                    for (i = -59; i <= 0; i++) {
                        data.push({
                            x: time + i * 1000,
                            y: 0
                        });
                    }
                    return data;
                })()
            }]
        });
    });
});

$(function () {
    $(document).ready(function() {
        Highcharts.setOptions({
            global: {
                useUTC: false
            }
        });
    
        var chart;
        var messagesReceivedPerSecond = 0;
		var dataPoints = new Array();
        chart = new Highcharts.Chart({
            chart: {
                renderTo: 'graph-players-latency',
                type: 'column',

                // Edit chart spacing
                spacingBottom: 0,
                spacingTop: 0,
                spacingLeft: 0,
                spacingRight: 0,

                // Explicitly tell the width and height of a chart
                width: null,
                height: 200,
                backgroundColor: 'rgb(237, 239, 241)',
                style: {
                    fontFamily: '"Helvetica Neue", Helvetica, Arial, sans-serif', 
                    fontSize: '14px',
                },
                events: {
                    load: function() {
    
                        // set up the updating of the chart each second
                        var series = this.series[0];
						latencyFunc = function(msg) {
							var point = msg;
							point.y = point.latency;
							if ((msg.latency >= 80) && (msg.latency < 100)) {
								point.color = 'orange';
							} else if (msg.latency >= 100) {
								point.color = 'red';
							}
							dataPoints.push(point);
							dataPoints.shift();
							//series.addPoint(y, false, true);
						};
                        setInterval(function() {
							/*
							if (latencyValues['Player 1'] != null){
								for(i = 0; i < latencyValues['Player 1'].length; i++) {
									var item = latencyValues['Player 1'].pop();
		                            var x = item[0], // timestamp
		                                y = item[1]; // average latency in last second
		                            series.addPoint(y, true, true);
								}
							}
							*/
							series.setData(dataPoints, true);
							//chart.redraw();
                        }, 1000);
                    }
                },
                credits: {
                  enabled: false
                },
            },
            title: {
                align: 'left',
                text: 'Players latency',
                style: {
                    color: '#555555',
                    fontFamily: '"Helvetica Neue", Helvetica, Arial, sans-serif', 
                    fontSize: '14px',
                }
            },
            xAxis: {
                labels: {
                    enabled: false
                },
                //type: 'datetime',
                //tickPixelInterval: 150
            },
            yAxis: {
                labels: {
                  x: 14,
                  y: 10,
                  color: '#808080',
                  style: {
                      fontSize: '9px'                  
                  }
                },
                title: {
                    enabled : false
                },
                plotLines: [{
                    value: 0,
                    width: 1,
                    color: '#cccccc'
                }]
            },
            plotOptions: {
              column: {
                pointWidth: 5,
                borderWidth: 0,
                colors: [
                    'rgb(58, 135, 173)',
                    'rgb(173, 135, 58)'
                ]
              }
            },
            tooltip: {
                //enabled: false,
                formatter: function() {
                        return 'Msg: ' + this.point.action + ' [' + this.point.msg + ']<br>Latency: ' + '<b>'+
                        Highcharts.numberFormat(this.y, 0) + '</b>' + ' msec';
                }
            }, 
            legend: {
                enabled: true
            },
            exporting: {
                enabled: false
            },
            series: [{
                name: 'Player 1',
                data: (function() {
                    // generate an array of random data
                    var data = [],
                        time = (new Date()).getTime(),
                        i;
    
                    for (i = -99; i <= 0; i++) {
                        dataPoints.push(0);
                    }
                    return dataPoints;
                })()
            }, {
                name: 'Player 2',
                data: (function() {
                    // generate an array of random data
                    var data = [],
                        time = (new Date()).getTime(),
                        i;
    
                    for (i = -99; i <= 0; i++) {
                        data.push(0);
                    }
                    return data;
                })()
            }]
        });
    });
});