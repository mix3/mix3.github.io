$(function(){
	// coderwall
	$.ajax({
		type: 'GET',
		url: 'http://coderwall.com/mix3.json?callback=display_coderwall',
		dataType: 'jsonp',
		jsonpCallback: 'display_coderwall',
		success: function (json) {
			var div = $('#coderwall');
			for (var i = 0, len = json.data.badges.length; i < len; i++) {
				div.append('<a href="http://coderwall.com/mix3"><img src="'+json.data.badges[i].badge+'" /></a>');
			}
		},
	});
	// toggle tree for archive
	$("ul.toggle_tree > li").prepend('<div class="toggle_tree_switch close float-left" style="width:13px;">-</div>');
	$("ul.toggle_tree li ul li").toggle();
	$("ul div.toggle_tree_switch").click(function(){
		$(this).toggleClass("close");
		if ($(this).hasClass("close")) {
			$(this).html("-");
		} else {
			$(this).html("+");
		}
		$(this).parent().find("li").toggle();
	});
	// toggle tree for tag
	$("ul.toggle_tree_2").append('<li class="more_switch">▼もっと</li>');
	$("ul.toggle_tree_2").append('<li class="hide_switch" style="display:none;">▲隠す</li>');
	$("ul.toggle_tree_2").find("li.hide").toggle();
	$("ul.toggle_tree_2 li.more_switch").click(function(){
		$(this).parent().find("li.hide").toggle();
		$(this).parent().find("li.hide_switch").toggle();
		$(this).toggle();
	});
	$("ul.toggle_tree_2 li.hide_switch").click(function(){
		$(this).parent().find("li.hide").toggle();
		$(this).parent().find("li.hide_switch").toggle();
		$(this).toggle();
	});
});
