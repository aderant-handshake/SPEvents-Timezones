// Use this function in a HTML5List View

function AdjustAllDayEventLV(isallday, d) {
    if (isallday) {
        var dt = kendo.parseDate(d);
        dt.setMinutes(dt.getMinutes() + dt.getTimezoneOffset());
        return dt;
    } else {
        return kendo.parseDate(d);
    }
}

// use this function in the onInitialize property of an HTML5Scheduler. 

function AdjustAllDayEvents(options, startField, endField, allDayField) {
    // assumes the following fields exist in the HS Class, unless you override 
    // in the call to the function in OnInitialize.
    startField = startField || "eventdatestart";
    endField = endField || "eventdateend";
    allDayField = allDayField || "eventisallday";

    options.dataSource.schema.parse = function (response) {
        events = [];
        for (var i = 0; i < response.d.results.length; i++) {
            var event = response.d.results[i];
            if (event[allDayField]) {
                try {
                    var dt = kendo.parseDate(event[startField]);
                    dt.setMinutes(dt.getMinutes() + dt.getTimezoneOffset());
                    event[startField] = dt;
                } catch(e) {
                    // nothing to do...
                }
                try {
                    var dt = kendo.parseDate(event[endField]);
                    dt.setMinutes(dt.getMinutes() + dt.getTimezoneOffset());
                    event[endField] = dt;
                } catch {
                    // nothing to do...
                }
            }
            events.push(event);
        }
        response.d.results = events;
        return response;
    };
};