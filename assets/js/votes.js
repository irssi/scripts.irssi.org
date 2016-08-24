(function(document, $){
    'use strict';
    var jsonpRe = /^\/\*[\s\S]*?\*\/jsonp\(([\s\S]*)\)$/m;

    function requestAll(start) {
	$.ajax({
	    accepts: { json: 'application/vnd.github.squirrel-girl-preview' },
	    dataType: 'json',
	    url: start,
	    jsonp: false,
	    jsonpCallback: 'jsonp',
	    dataFilter: function(dta, typ) {
		if (typ == "json") {
		    return dta.replace(jsonpRe, "$1");
		}
		return dta;
	    }
	})
	    .done(function(r) {
		var remaining = r.meta['X-RateLimit-Remaining'];
		var rateReset = r.meta['X-RateLimit-Reset'];
		var timeOut = 0;
		var hasMore = false;
		if (remaining < 10) {
		    timeOut = 1000 + rateReset * 1000 - (new Date() / 1);
		}
		if (timeOut < 0) timeOut = 0;
		if (r.meta.Link) {
		    r.meta.Link.forEach(function(l) {
			if (l[1].rel == "next") {
			    window.setTimeout(function(){requestAll(l[0]);}, timeOut);
			    hasMore = true;
			    return;
			}
		    });
		}
		if (timeOut > 0) {
		    timeOut += 1000;
		}

		r.data.forEach(function(e) {
		    e.body = e.body.replace(/\r/g, "");
		    var redir = e.body.match(/^#(\d+)$/);
		    if (redir) {
			var l = start.replace(/(\/issues\/)\d+(\/comments\?)/, "$1" + redir[1] + "$2").replace(/&.*/, "");
			window.setTimeout(function(){requestAll(l);}, timeOut);
			hasMore = true;
			return;
		    }
			
		    var lines = e.body.split("\n");
		    var script = lines[0].replace(/[^-a-zA-Z0-9_]/g, "_");
		    if (script == "comment") {
			script = "adv_windowlist_pl";
		    }
		    var st = "#script-" + script + " .votes";
		    var row = $(st);
		    if (row.length) {
			var votes = 1+ e.reactions['+1'] - e.reactions['-1'];
			var link = "＊";
			if (e.reactions['heart'] >= votes) {
			    link = "💜";
			}
			row.html( "" + votes );
			
			row.append("<span><a data-toggle=\"tooltip\" title=\"vote on github\" href=\"" + e.html_url + "\">"+link+"</a></span>");
		    }
		});
		if (!hasMore) {
		    $("#th-votes").html("Votes");
		}
	    });
    }
    requestAll('https://api.github.com/repos/ailin-nemui/scripts.irssi.org/issues/2/comments?callback=jsonp');
})(document, $);
