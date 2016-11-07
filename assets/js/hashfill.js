(function(document, $) {
    'use strict';

    function readhash() {
	var kv = window.location.hash.substr(1).split('&');
	for(var i = 0; i < kv.length; i++) {
	    var p = kv[i].split('=');
	    var e = $(':input').filter(function(i, e) {
		return (e.dataset||{}).name === p[0];
	    });
	    if (e && e[0]) {
		e[0].value = decodeURIComponent(p[1].replace(/[+]/g, '%20'));
		if ('createEvent' in document) {
		    var ev = document.createEvent('HTMLEvents');
		    ev.initEvent('input', true, false);
		    e[0].dispatchEvent(ev);
		}
	    }
	}
    }

    if ('onhashchange' in window) {
	$(window).bind('hashchange', readhash);
    }

    document.addEventListener('readystatechange', function() {
	if (document.readyState === 'complete') {
	    readhash();
	}
    });

})(document, $);
