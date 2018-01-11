$(document).ready(function()
{
	var loader_beendet = false;
	var www_beendet = false;
	var refTimer;
	var lastprozent = 0;
	
	function b2h(bytes, precision)
	{
		var kilobyte = 1024;
		var megabyte = kilobyte * 1024;
		var gigabyte = megabyte * 1024;
		var terabyte = gigabyte * 1024;
	   
		if ((bytes >= 0) && (bytes < kilobyte)) {
			return bytes + ' B';
	 
		} else if ((bytes >= kilobyte) && (bytes < megabyte)) {
			return (bytes / kilobyte).toFixed(precision) + ' KB';
	 
		} else if ((bytes >= megabyte) && (bytes < gigabyte)) {
			return (bytes / megabyte).toFixed(precision) + ' MB';
	 
		} else if ((bytes >= gigabyte) && (bytes < terabyte)) {
			return (bytes / gigabyte).toFixed(precision) + ' GB';
	 
		} else if (bytes >= terabyte) {
			return (bytes / terabyte).toFixed(precision) + ' TB';
	 
		} else {
			return bytes + ' B';
		}
	}
	
	function loadData()
	{
		$.getJSON("status.json", function(data)
		{
			console.log(data);
			console.log("Version: " + data.BASHLoader[0].version);
			console.log("date: " + data.BASHLoader[0].date);
			console.log("datetime: " + data.BASHLoader[0].datetime);
			console.log("status: " + data.BASHLoader[0].status);
			console.log("sfdl: " + data.BASHLoader[0].sfdl);
			console.log("action: " + data.BASHLoader[0].action);
			console.log("loading_mt_files: " + data.BASHLoader[0].loading_mt_files);
			console.log("loading_total_files: " + data.BASHLoader[0].loading_total_files);
			console.log("loading: " + data.BASHLoader[0].loading);
			console.log("loading_file_array: " + data.BASHLoader[0].loading_file_array);
			
			var version = data.BASHLoader[0].version;
			var status = data.BASHLoader[0].status;
			var date = data.BASHLoader[0].date;
			var datetime = data.BASHLoader[0].datetime;
			var sfdl = data.BASHLoader[0].sfdl;
			var action = data.BASHLoader[0].action;
			var loading_mt_files = data.BASHLoader[0].loading_mt_files;
			var loading_total_files = data.BASHLoader[0].loading_total_files;
			var loading = data.BASHLoader[0].loading;
			var loading_file_array = data.BASHLoader[0].loading_file_array;
			
			if(www_beendet == false)
			{
				$(".button_sfdl_link").prop("disabled", false);
				$(".button_ftp").prop("disabled", false);
				$(".button_upload").prop("disabled", false);
				$(".button_kill").prop("disabled", false);
			}
			
			if(loader_beendet == false)
			{
				if(status == "done")
				{
					$(".button_start").prop("disabled", false);
					$(".button_stop").prop("disabled", true);
				}
				else
				{
					$(".button_start").prop("disabled", true);
					$(".button_stop").prop("disabled", false);
				}
			}
			else
			{
				$(".button_start").prop("disabled", false);
				$(".button_stop").prop("disabled", true);
			}
			
			$('.title').html("BASH-Loader v" + version);
			if(action == "NULL")
			{
				action = "done"
			}
			$('.info').html("Status: <b>" + status + "</b> | Letzte Aktivit&auml;t: <b>" + datetime + "</b>");
			
			if(action == "loading")
			{
				if(sfdl.length > 75)
				{
					sfdl = sfdl.substring(0,75);
					sfdl += "...";
				}
			
				$('.loader_head').html("Aktuell wird geladen ...<br /><b>" + sfdl + "</b><br />Insgesamt werden <b>" + loading_total_files + "</b> Dateien geladen und davon immer <b>" + loading_mt_files + "</b> gleichzeitig.");
				
				var load_arr = loading.split("|");
				var progproz = load_arr[3];
				if(!progproz)
				{
					progproz = 0;
				}
				$('.loader_progress').html(load_arr[0] + " (" + b2h(load_arr[1] * 1024, 2) + " von " + b2h(load_arr[2] * 1024, 2) + " geladen) <progress max=100 value=" + progproz + "></progress> " + progproz + "% " + load_arr[4] + " MB/s [" + load_arr[5] + "]");
				
				$('.loader_files').html("");
				var files_arr = loading_file_array.split(";");
				for(var i = 0; i < files_arr.length; i++)
				{
					var files_split = files_arr[i].split("|");
					var filename = files_split[0];
					
					if(filename.length > 40)
					{
						filename = filename.substring(0,40);
						filename += "...";
					}
					
					if(files_split[2] == "NULL")
					{
						$('.loader_files').append("<ul class=\"loader_items\"><li style=\"width: 450px;\"><b>" + filename + "</b><li><li style=\"width: 170px;\">(" + b2h(files_split[1], 2) + ")</li><li><progress max=100 value=0></progress></li><li>0%</ul>");
					}
					else
					{
						var prozent = 0;
						if(files_split[2])
						{
							prozent = Math.round(files_split[2] / files_split[1] * 100);
						}
						$('.loader_files').append("<ul class=\"loader_items\"><li style=\"width: 450px;\"><b>" + filename + "</b><li><li style=\"width: 170px;\">(" + b2h(files_split[1], 2) + " / " + b2h(files_split[2], 2) + ")</li><li><progress max=100 value=" + prozent + "></progress></li><li>" + prozent + "%</ul>");
					}
				}
				$(".loader_items:even").css("background-color","#fcfcfc"); 
				$(".loader_items:odd").css("background-color","#f3f3f3");
			}
			else
			{
				if(action == "done")
				{
					$('.loader_progress').html("");
					$('.loader_files').html("");
					$('.loader_head').html("<b>B E R E I T !</b><br /><br />BASH-Loader ist nun beendet.<br />Bitte weitere SFDL Dateien hinzuf&uuml;gen / hochladen und BASH-Loader starten.");
				}
				else
				{
					$('.loader_head').html(action);
				}
			}
		});
	
		refTimer = setTimeout(loadData, 1000);
	}
	
	$(".button_start").click(function() {
		var usrpass = prompt("Bitte Passwort zum Starten des BASH-Loaders eingeben", "");
		if(usrpass)
		{
			$.get("/start/" + usrpass, function(data) {
				var command = data.BASHLoader[0].start
				if(command == "ok")
				{
					loader_beendet = false;
					
					alert("BASH-Loader erfolgreich gestartet!");
				}
				else
				{
					alert("Fehler: " + command);
				}
			});
		}
	});
	
	$(".button_stop").click(function() {
		var usrpass = prompt("Bitte Passwort zum Beenden des BASH-Loaders eingeben", "");
		if(usrpass)
		{
			$.get("/stop/" + usrpass, function(data) {
				var command = data.BASHLoader[0].stop
				if(command == "ok")
				{
					loader_beendet = true;
					
					$(".button_start").prop("disabled", false);
					$(".button_stop").prop("disabled", true);
				
					alert("BASH-Loader erfolgreich beendet!");
				}
				else
				{
					alert("Fehler: " + command);
				}
			});
		}
	});
	
	$(".button_kill").click(function() {
		var usrpass = prompt("Bitte Passwort zum Beenden des Webservers eingeben", "");
		if(usrpass)
		{
			$.get("/kill/" + usrpass, function(data) {
				var command = data.BASHLoader[0].kill
				if(command == "ok")
				{	
					www_beendet = true;
					
					$(".button_start").prop("disabled", true);
					$(".button_stop").prop("disabled", true);
					$(".button_kill").prop("disabled", true);
					$(".button_sfdl_link").prop("disabled", true);
					$(".button_ftp").prop("disabled", true);
					$(".button_upload").prop("disabled", true);
				
					alert("BASH-Loader Webserver beendet!");
					
					clearTimeout(refTimer);
				}
				else
				{
					alert("Fehler: " + command);
				}
			});
		}
	});
	
	$(".button_sfdl_link").click(function() {
		var command = prompt("Bitte Link zur SFDL Datei eingeben", "");
		if(command)
		{
			$.get("/upload/" + command, function(data) {
				var command = data.BASHLoader[0].upload
				if(command == "ok")
				{
					alert("SFDL Datei (" + data.BASHLoader[0].sfdl + ") erfolgreich hochgeladen!");
				}
				else
				{
					alert("Fehler: " + data.BASHLoader[0].sfdl);
				}
			});
		}
	});
	
	$(".button_ftp").click(function() {
		var command = prompt("Bitte FTP URL eingeben", "");
		if(command)
		{
			$.get("/addftp/" + command, function(data) {
				var command = data.BASHLoader[0].status
				if(command == "ok")
				{
					alert("SFDL Datei (" + data.BASHLoader[0].msg + ") erfolgreich hochgeladen!");
				}
				else
				{
					alert("Fehler: " + data.BASHLoader[0].msg);
				}
			});
		}
	});
	
	$(".button_upload").click(function() {
		$('input[type=file]').trigger('click');
	});

	$('input[type=file]').change(function() {
		var fileup = $(this).val(), fileup = fileup.length ? fileup.split('\\').pop() : '';
		
		// console.log("SFDL Upload: " + fileup);
		
		var data = new FormData();
		data.append("sfdl", this.files[0], fileup);
		
		$.ajax({
			url: '/file',
			data: data,
			cache: false,
			contentType: false,
			processData: false,
			type: 'POST',
			success: function(data) {
				var status = data.BASHLoader[0].upload;
				if(status == "ok")
				{
					alert("SFDL Datei (" + data.BASHLoader[0].sfdl + ") erfolgreich hochgeladen!");
				}
				else
				{
					alert("Fehler: " + data.BASHLoader[0].sfdl);
				}
			}
		});
	});
	
	loadData();
});