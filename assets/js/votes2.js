(function(document){
    'use strict';
    function sort() {
	var myTH = $("#th-votes");
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
    function signalDone() {
	var myTH = $("#th-votes");
	myTH.html("Votes");
	if (window.sorttable && window.sorttable.MADE) {
	    sort();
	} else {
	    if (!window.sortSorttable) { window.sortSorttable = {}; }
	    sortSorttable.votes = sort;
	}
    }
    function addVotes(d) {
	var script;
	for (script in d) {
	    var sn = script.replace(/[^-a-zA-Z0-9_]/g, "_");
	    var row = $("#script-" + sn + " .votes");
	    if (row.length) {
		var votes = d[script].v;
		var link = "＊";
		if (d[script].h) link = "💜";
		row.html( "" + votes  );
		row.append("<span><a data-toggle=\"tooltip\" title=\"vote on github\" href=\""
			   + d[script].u + "\">"+link+"</a></span>");
		row.attr("sorttable_customkey", 9999+votes);
	    }
	}
	signalDone();
    }

    window.addVotes = addVotes;
})(document);
