/*
Copyright (c) 2003-2009, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/

CKEDITOR.editorConfig = function( config )
{
	// Define changes to default configuration here. For example:
	// config.language = 'fr';
	
	config.skin = 'office2003';
	
	
	// A simpler toolbar for BugTracker.NET
	config.toolbar_Btnet=[
		
		['Cut','Copy','Paste','PasteText','-','SpellChecker','Scayt','-',
		'Undo','Redo','-',
		'Find','Replace','-', 
		'Link','Unlink','-',
		'Image','Table','SpecialChar','-',
		'NumberedList','BulletedList','-',
		'About'],
		'/',
		
		['Bold','Italic','Underline','Strike','-',
		'Font','FontSize','-',
		'TextColor','BGColor','-',
		'Outdent','Indent','-',
		'JustifyLeft','JustifyCenter','JustifyRight']
		
		];
	
	
	CKEDITOR.config.toolbar='Btnet';
	
	// Turn off the elementspath plugin for BugTracker.NET
	config.plugins = config.plugins.replace( /(?:^|,)elementspath(?=,|$)/, '' );
	
};
