(function(document, $){
    'use strict';
    var ghLimits = {search: {}, core: {}};
    var linkRe = /\s*<([^>]*)>;\s*rel=(["'])(.*?)\2\s*(?:,|$)/g;
    var stopId = 0;
    var queue = {search: [], core: []};
    var todo = 1;

    function requestLater(what, how, arg) {
	var when = rateTimeout(what);
	if (when >= 0) {
	    var empty = queue[what].length == 0;
	    queue[what].push([how, arg]);
	    if (empty && when > 2000 && console && console.log) {
		console.log("rate limit on: ", arg, "time to wait: ",
			    (when > 120 * 1000 ? Math.ceil(when / 1000 / 60) + " m" : Math.ceil(when / 1000) + " s"));
	    }
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
	if (!todo) {
	    var myTH = $("#th-votes");
	    myTH.html("Votes");
	    var isSorted = [0];
	    Array.prototype.forEach.call(myTH[0].parentNode.children, function(e) {
		if (e.classList.contains("sorttable_sorted") || e.classList.contains("sorttable_sorted_reverse")) {
		    isSorted[0] = 1;
		}
	    });
	    if (!isSorted[0]) {
		sorttable.innerSortFunction.apply(myTH[0].parentNode.children[0], []);
		sorttable.innerSortFunction.apply(myTH[0].parentNode.children[0], []);
		sorttable.innerSortFunction.apply(myTH[0], []);
		sorttable.innerSortFunction.apply(myTH[0], []);
	    }
	}
    }

    function jj(url) {
	return $.ajax({
	    accepts: { json: 'application/vnd.github.squirrel-girl-preview' },
	    dataType: 'json',
	    url: url,
	    jsonp: false
	});
    }

    function searchVotes(url) {
	var start = url.indexOf("//") !== -1 ? url
		: 'https://api.github.com/search/issues?q=votes+in:title+state:closed+type:issue+'
		+ 'repo:' + url + ';sort=updated';
	jj(start).done(function(r, textStatus, $xhr) {
	    var hasMore = fetchNext('search', $xhr, searchVotes);
	    if (hasMore) { todo++; }
	    r.items.forEach(function(e) {
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

    function updateLimits(what, $xhr) {
	ghLimits[what].remaining = ~~ $xhr.getResponseHeader('X-RateLimit-Remaining');
	ghLimits[what].reset = ~~ $xhr.getResponseHeader('X-RateLimit-Reset');
    }

    function fetchNext(what, $xhr, how) {
	var hasMore = false;
	updateLimits(what, $xhr);
	var link = $xhr.getResponseHeader('Link');
	if (link) {
	    var l;
	    while ((l = linkRe.exec(link))) {
		if (l[3] == "next") {
		    hasMore = true;
		    requestLater(what, how, l[1]);
		}
	    }
	}
	return hasMore;
    }

    function requestComments(start) {
	jj(start).done(function(r, textStatus, $xhr) {
	    updateLimits('core', $xhr);
	    if ($xhr.status == 403 && !$xhr.getResponseHeader('X-RateLimit-RateLimit')) {
		requestLater('core', requestComments, start);
		return;
	    }
	    //var hasMore = fetchNext('core', $xhr, requestComments);
	    //if (hasMore) todo++;
	    r.some(function(e) {
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
	    ghLimits = r.resources;
	    requestLater(what, how, arg);
	});
    }

    limitsThen('search', searchVotes, 'ailin-nemui/scripts.irssi.org');

})(document, $);
