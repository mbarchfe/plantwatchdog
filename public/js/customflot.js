function Graph(placeholder_id) {
    this.placeholder_id = placeholder_id
    this.placeholder = $(placeholder_id);
    this.data = [];
    this.options = {   xaxis: { mode: "time" },
                      crosshair: { mode: "x" },
                      grid: { hoverable: true, autoHighlight: false },
                      selection: { mode: "xy" },  
                      legend: { position: "nw" }       
                   };
    var self = this;            
    this.placeholder.bind("plotselected", function(event, ranges) { self.plotselected(ranges) } );
    this.placeholder.bind("plothover", function (event, pos, item) { self.plothover(self, pos) } );
    this.updateLegendTimeout = null;
    this.latestPosition = null;
    this.seriesFilter = function(series) { return true; }
}

Graph.prototype.customPlot = function() {
   // first plot the graph ..
   this.plot = $.plot(this.placeholder, this.series.filter(this.seriesFilter), this.options);
   // .. and then the zoom and pan buttons
   var plotOffset = this.plot.getPlotOffset(); // the plotOffset marks the grid area (i.e. it depends on the width of the axis labels)
   var margin = 5;
   // every plot clears the placeholders' html, so we have to re-add the button after every plot
   var self = this;
   $('<div class="button" style="position:absolute;right:'+(plotOffset.right + margin)+'px;top:'+(plotOffset.top + margin)+'px">zoom out</div>').appendTo(this.placeholder).click(function (e) {
      e.preventDefault();
      self.options.xaxis.min=null;
      self.options.xaxis.max=null;
      self.options.yaxis.min=null;
      self.options.yaxis.max=null;
      self.customPlot();
    });
    // panning arrows
    function addArrow(dir, relativeRight, relativeTop, offset) {
      var right = plotOffset.right + margin + relativeRight;
      var top = plotOffset.top + margin + 30 + relativeTop;
      $('<img class="button" src="images/arrow-' + dir + '.gif" style="position:absolute;right:' + right + 'px;top:' + top + 'px" alt="' + dir + '">').appendTo(self.placeholder).click(function (e) {
        e.preventDefault();
        self.plot.pan(offset);
      });
    }

    addArrow('up', 15, 0, { top: -100 });
    addArrow('left', 30, 15, { left: -100 });
    addArrow('right', 0, 15, { left: 100 });
    addArrow('down', 15, 30, { top: 100 }); 
}

Graph.prototype.submitForm = function() {
       var self = this;
       self.placeholder.html("");
       self.placeholder.addClass('loading');
        // then fetch the data with jQuery
       $.ajax( {
            url: this.urlfunction(),
            type: 'get',
            dataType: 'json',
            success: function(data) {
              // at this point this has been switched
              // therefore we have saved it to self which is still in the scope
              self.placeholder.removeClass('loading');
              self.series = data
              self.customPlot();
            }
        });
        return false; // no default handling    
}

Graph.prototype.plotselected = function(ranges) {
        // clamp the zooming to prevent eternal zoom
        if (ranges.xaxis.to - ranges.xaxis.from < 0.00001)
            ranges.xaxis.to = ranges.xaxis.from + 0.00001;
        if (ranges.yaxis.to - ranges.yaxis.from < 0.00001)
            ranges.yaxis.to = ranges.yaxis.from + 0.00001;
        // do the zooming
        this.options = $.extend(true, {}, this.options, {
                           xaxis: { min: ranges.xaxis.from, max: ranges.xaxis.to },
                           yaxis: { min: ranges.yaxis.from, max: ranges.yaxis.to }
                         });
        this.customPlot();
};

Graph.prototype.updateLegend= function() {
        this.updateLegendTimeout = null;
        var pos = this.latestPosition;
        var axes = this.plot.getAxes();
        if (pos.x < axes.xaxis.min || pos.x > axes.xaxis.max ||
            pos.y < axes.yaxis.min || pos.y > axes.yaxis.max) {
            return;
        }
        var legends = $(this.placeholder_id +" .legendLabel");
        var i, j, dataset = this.plot.getData();
        for (i = 0; i < dataset.length; ++i) {
            var series = dataset[i];

            // find the nearest points, x-wise
            for (j = 0; j < series.data.length; ++j)
                if (series.data[j][0] > pos.x)
                    break;
            
            // now interpolate
            var y, p1 = series.data[j - 1], p2 = series.data[j];
            if (p1 == null)
                y = p2[1];
            else if (p2 == null)
                y = p1[1];
            else
                y = p1[1] + (p2[1] - p1[1]) * (pos.x - p1[0]) / (p2[0] - p1[0]);
            legends.eq(i).text(series.label.replace(/=.*/, "= " + y.toFixed(2)));
        }
    }
    
Graph.prototype.plothover=function(self, pos) { 
     self.latestPosition = pos;
     if (!self.updateLegendTimeout) {
          self.updateLegendTimeout = setTimeout(function() { self.updateLegend() }, 50);
     }
};