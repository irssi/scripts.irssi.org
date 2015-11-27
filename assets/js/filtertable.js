/*
 LightTableFilter by Chris Coyier
 http://codepen.io/chriscoyier/pen/tIuBL
 */
(function(document) {
    'use strict';

    var LightTableFilter = (function(Arr) {

	var _input;

	function _onInputEvent(e) {
	    _input = e.target;
	    var tables = document.getElementsByClassName(_input.getAttribute('data-table'));
	    Arr.forEach.call(tables, function(table) {
		Arr.forEach.call(table.tBodies, function(tbody) {
		    Arr.forEach.call(tbody.rows, _filter);
		});
	    });
	}

	function _filterExpr(val, text) {
	    return !val.split(' ').every(function(word) {
		if (word.charAt(0) === '-') {
		    return text.indexOf(word.substring(1)) === -1;
		} else {
		    return text.indexOf(word) !== -1;
		}
	    });
	}

	function _filter(row) {
	    var text = row.textContent.toLowerCase(), val = _input.value.toLowerCase();
	    row.style.display = _filterExpr(val, text) ? 'none' : 'table-row';
	}

	return {
	    init: function() {
		var inputs = document.getElementsByClassName('light-table-filter');
		Arr.forEach.call(inputs, function(input) {
		    input.oninput = _onInputEvent;
		});
	    }
	};
    })(Array.prototype);

    document.addEventListener('readystatechange', function() {
	if (document.readyState === 'complete') {
	    LightTableFilter.init();
	}
    });

})(document);
