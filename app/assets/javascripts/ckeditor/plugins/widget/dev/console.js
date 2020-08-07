/**
 * @license Copyright (c) 2003-2014, CKSource - Frederico Knabben. All rights reserved.
 * For licensing, see LICENSE.md or http://ckeditor.com/license
 */
"use strict";(function(){function e(e){var t="",r;for(var i=0;i<e.length;++i)r=e[i],t+=n.output({id:r.id,name:r.name,data:JSON.stringify(r.data)});return t}function t(e){var t=[];for(var n in e)t.push(e[n]);return t}CKCONSOLE.add("widget",{panels:[{type:"box",content:'<ul class="ckconsole_list ckconsole_value" data-value="instances"></ul>',refresh:function(n){var r=t(n.widgets.instances);return{header:"Instances ("+r.length+")",instances:e(r)}},refreshOn:function(e,t){e.widgets.on("instanceCreated",function(e){t(),e.data.on("data",t)}),e.widgets.on("instanceDestroyed",t)}},{type:"box",content:'<ul class="ckconsole_list"><li>focused: <span class="ckconsole_value" data-value="focused"></span></li><li>selected: <span class="ckconsole_value" data-value="selected"></span></li></ul>',refresh:function(e){var t=e.widgets.focused,n=e.widgets.selected,r=[];for(var i=0;i<n.length;++i)r.push(n[i].id);return{header:"Focus &amp; selection",focused:t?"id: "+t.id:"-",selected:r.length?"id: "+r.join(", id: "):"-"}},refreshOn:function(e,t){e.on("selectionCheck",t,null,null,999)}},{type:"log",on:function(e,t,n){e.on("selectionChange",function(n){var r="selection change",i=n.data.selection,s=i.getSelectedElement(),o;s&&(o=e.widgets.getByElement(s,!0))&&(r+=" (id: "+o.id+")"),t(r)},null,null,1),e.widgets.on("instanceDestroyed",function(e){t("instance destroyed (id: "+e.data.id+")")},null,null,1),e.widgets.on("instanceCreated",function(e){t("instance created (id: "+e.data.id+")")},null,null,1),e.widgets.on("widgetFocused",function(e){t("widget focused (id: "+e.data.widget.id+")")},null,null,1),e.widgets.on("widgetBlurred",function(e){t("widget blurred (id: "+e.data.widget.id+")")},null,null,1),e.widgets.on("checkWidgets",n("checking widgets"),null,null,1),e.widgets.on("checkSelection",n("checking selection"),null,null,1)}}]});var n=new CKEDITOR.template("<li>id: <code>{id}</code>, name: <code>{name}</code>, data: <code>{data}</code></li>")})();