(function(document, $){
    'use strict';
    var jsonpRe = /^\/\*[\s\S]*?\*\/jsonp\(([\s\S]*)\)$/m;
    var ghLimits = {search: {}, core: {}};
    var stopId = 0;
    var queue = {search: [], core: []};
    var todo = 1;

    function requestLater(what, how, arg) {
	var when = rateTimeout(what);
	if (when >= 0) {
	    var empty = queue[what].length == 0;
	    queue[what].push([how, arg]);
	    if (empty) window.setTimeout(function(){reQueue(what);}, when);
	} else {
	    ghLimits[what].remaining--;
	    how(arg);
	}
    }

    function reQueue(what) {
	limitsThen(what, function(q) {
	    q.forEach(function(e) {
		requestLater(what, e[0], e[1]);
	    });
	}, queue[what].splice(0, queue[what].length));
    }

    function signalDone() {
	if (!todo) $("#th-votes").html("Votes");
    }

    function _jsonpToJson(dta, typ) {
	if (typ == "json") {
	    return dta.replace(jsonpRe, "$1");
	}
	return dta;
    }

    function jj(url) {
	return $.ajax({
	    accepts: { json: 'application/vnd.github.squirrel-girl-preview' },
	    dataType: 'json',
	    url: url + (url.indexOf('callback=') === -1
			? (url.indexOf('?') === -1 ? '?' : ';') + 'callback=jsonp'
			: ''),
	    jsonp: false,
	    jsonpCallback: 'jsonp',
	    dataFilter: _jsonpToJson
	});
    }

    function searchVotes(url) {
	var start = url.indexOf("//") !== -1 ? url
		: 'https://api.github.com/search/issues?q=votes+in:title+state:closed+type:issue+'
		+ 'repo:' + url + ';sort=updated';
	jj(start).done(function(r) {
	    var hasMore = fetchNext('search', r.meta, searchVotes);
	    if (hasMore) { todo++; }
	    r.data.items.forEach(function(e) {
		if (stopId && e.number > stopId) return;
		if (e.title != "votes") return;
		if (e.locked) { stopId = e.number; return; }
		todo++;
		requestLater('core', requestComments, e.comments_url);
		todo++;
		requestLater('core', requestComments, e.comments_url + '?page=2');
		todo++;
		requestLater('core', requestComments, e.comments_url + '?page=3');
		//todo++;
		//requestLater('core', requestComments, e.comments_url + '?page=4');
	    });
	    todo--;
	    signalDone();
	});
    }

    function rateTimeout(what) {
	if ($.isEmptyObject(ghLimits[what])) { return -1; }

	var remaining = ghLimits[what].remaining;
	var rateReset = ghLimits[what].reset;
	var limit = ghLimits[what].limit;

	var timeOut = -1;
	if (remaining < Math.log(limit) + Math.sqrt(limit)) {
	    timeOut = 1000 + rateReset * 1000 - (new Date() / 1);
	    if (timeOut < -1) timeOut = 0;
	}
	return timeOut;
    }

    function updateLimits(what, meta) {
	ghLimits[what].remaining = ~~ meta['X-RateLimit-Remaining'];
	ghLimits[what].reset = ~~ meta['X-RateLimit-Reset'];
    }

    function fetchNext(what, meta, how) {
	var hasMore = false;
	updateLimits(what, meta);
	if (meta.Link) {
	    meta.Link.forEach(function(l) {
		if (l[1].rel == "next") {
		    hasMore = true;
		    requestLater(what, how, l[0]);
		    return;
		}
	    });
	}
	return hasMore;
    }

    function requestComments(start) {
	jj(start).done(function(r) {
	    updateLimits('core', r.meta);
	    if (r.meta.status == 403 && !r.meta['X-RateLimit-RateLimit']) {
		requestLater('core', requestComments, start);
		return;
	    }
	    //var hasMore = fetchNext('core', r.meta, requestComments);
	    //if (hasMore) todo++;
	    r.data.some(function(e) {
		e.body = e.body.replace(/\r/g, "");
		var lines = e.body.split("\n");
		var redir = e.body.match(/^#(\d+)$/);
		if (redir) return true;
		var script = lines[0].replace(/^## /, "").replace(/[^-a-zA-Z0-9_]/g, "_");
		var row = $("#script-" + script + " .votes");
		if (row.length) {
		    var votes = 1+ e.reactions['+1'] - e.reactions['-1'];
		    var link = "＊";
		    if (e.reactions['heart'] >= votes) link = "💜";
		    row.html( "" + (e.reactions['+1'] == 0 && e.reactions['-1'] == 0 ? "" : votes-1)  );
		    row.append("<span><a data-toggle=\"tooltip\" title=\"vote on github\" href=\""
			       + e.html_url + "\">"+link+"</a></span>");
		    row.attr("sorttable_customkey", 9999+votes);
		}
		return false;
	    });
	    todo--;
	    signalDone();
	});
    }

    function limitsThen(what, how, arg) {
	jj('https://api.github.com/rate_limit').done(function(r) {
	    ghLimits = r.data.resources;
	    requestLater(what, how, arg);
	});
    }

    limitsThen('search', searchVotes, 'ailin-nemui/scripts.irssi.org');

})(document, $);
