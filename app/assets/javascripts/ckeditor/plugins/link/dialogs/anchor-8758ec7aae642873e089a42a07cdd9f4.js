/*
 Copyright (c) 2003-2014, CKSource - Frederico Knabben. All rights reserved.
 For licensing, see LICENSE.md or http://ckeditor.com/license
*/
CKEDITOR.dialog.add("anchor",function(e){var t=function(e){this._.selectedElement=e,this.setValueOf("info","txtName",e.data("cke-saved-name")||"")};return{title:e.lang.link.anchor.title,minWidth:300,minHeight:60,onOk:function(){var t=CKEDITOR.tools.trim(this.getValueOf("info","txtName")),t={id:t,name:t,"data-cke-saved-name":t};if(this._.selectedElement)this._.selectedElement.data("cke-realelement")?(t=e.document.createElement("a",{attributes:t}),e.createFakeElement(t,"cke_anchor","anchor").replace(this._.selectedElement)):this._.selectedElement.setAttributes(t);else{var n=e.getSelection(),n=n&&n.getRanges()[0];n.collapsed?(CKEDITOR.plugins.link.synAnchorSelector&&(t["class"]="cke_anchor_empty"),CKEDITOR.plugins.link.emptyAnchorFix&&(t.contenteditable="false",t["data-cke-editable"]=1),t=e.document.createElement("a",{attributes:t}),CKEDITOR.plugins.link.fakeAnchor&&(t=e.createFakeElement(t,"cke_anchor","anchor")),n.insertNode(t)):(CKEDITOR.env.ie&&9>CKEDITOR.env.version&&(t["class"]="cke_anchor"),t=new CKEDITOR.style({element:"a",attributes:t}),t.type=CKEDITOR.STYLE_INLINE,e.applyStyle(t))}},onHide:function(){delete this._.selectedElement},onShow:function(){var n=e.getSelection(),r=n.getSelectedElement();if(r)CKEDITOR.plugins.link.fakeAnchor?((n=CKEDITOR.plugins.link.tryRestoreFakeAnchor(e,r))&&t.call(this,n),this._.selectedElement=r):r.is("a")&&r.hasAttribute("name")&&t.call(this,r);else if(r=CKEDITOR.plugins.link.getSelectedLink(e))t.call(this,r),n.selectElement(r);this.getContentElement("info","txtName").focus()},contents:[{id:"info",label:e.lang.link.anchor.title,accessKey:"I",elements:[{type:"text",id:"txtName",label:e.lang.link.anchor.name,required:!0,validate:function(){return this.getValue()?!0:(alert(e.lang.link.anchor.errorName),!1)}}]}]}});