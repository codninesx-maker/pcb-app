import 'dart:html' as html;
String getWebWindowHash() => html.window.location.hash;
void clearWebWindowHash() { html.window.history.replaceState(null, '', html.window.location.pathname); }
