/**
 * @author Remy Sharp
 * @date 2008-02-25
 * @url http://remysharp.com/2007/09/18/auto-populate-multiple-select-boxes/
 * @license Creative Commons License - ShareAlike http://creativecommons.org/licenses/by-sa/3.0/
 */


(function ($) {
    $.fn.selectChain = function (options, dynamic_data) {
        var defaults = {
            key: "id",
            value: "label"
        };
        
        var settings = $.extend({}, defaults, options);
        
        if (!(settings.target instanceof $)) settings.target = $(settings.target);
        
        
        return this.each(function () {
            var $$ = $(this);
            
            $$.change(function () {
                var data = null;
                if (dynamic_data != null) {
                    dynamic_data(settings);
                } 
                
                settings.target.empty();
                
                $.ajax({
                    url: settings.url,
                    data: data,
                    type: (settings.type || 'get'),
                    dataType: 'json',
                    success: function (j) {
                        var options = [], i = 0, o = null;
                        
                        for (i = 0; i < j.length; i++) {
                            // required to get around IE bug (http://support.microsoft.com/?scid=kb%3Ben-us%3B276228)
                            o = document.createElement("OPTION");
                            o.value = typeof j[i] == 'object' ? j[i][settings.key] : j[i];
                            o.text = typeof j[i] == 'object' ? j[i][settings.value] : j[i];
                            settings.target.get(0).options[i] = o;
                        }

			// hand control back to browser for a moment
			setTimeout(function () {
			    settings.target
                                .find('option:l')
                                .attr('selected', 'selected')
                                .parent('select')
                                .trigger('change');
			}, 0);
                    },
                    error: function (xhr, desc, er) {
			        alert("Could not load " + settings.url);
                    }
                });
            });
        });
    };
    $.fn.selectedOption = function() 
    {
    	var result = 0;
    	var sels = $(this).each( function() { result = this.options[this.selectedIndex].value});
    	return result;
    }
})(jQuery);