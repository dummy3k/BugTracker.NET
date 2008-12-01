<%@ Page language="C#"%>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->


<script language="C#" runat="server">


Security security;

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	
	security = new Security();
	security.check_security( HttpContext.Current, Security.MUST_BE_ADMIN);

	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ "admin";

}


</script>

<html>
<head>
<title id="titl" runat="server">btnet admin</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body>
<% security.write_menu(Response, "admin"); %>
<div class=align><table border=0><tr><td>
<ul>
<p>
<li class=listitem><a href=users.aspx>users</a>
<p>
<li class=listitem><a href=orgs.aspx>organizations</a>
<p>
<li class=listitem><a href=projects.aspx>projects</a>
<p>
<li class=listitem><a href=categories.aspx>categories</a>
<p>
<li class=listitem><a href=priorities.aspx>priorities</a>
<p>
<li class=listitem><a href=statuses.aspx>statuses</a>
<p>
<li class=listitem><a href=udfs.aspx>user defined attribute</a>
&nbsp;&nbsp;<span class=smallnote>(see "ShowUserDefinedBugAttribute" and "UserDefinedBugAttributeName" in Web.config)</span>
<p>
<li class=listitem><a href=customfields.aspx>custom fields</a>
&nbsp;&nbsp;<span class=smallnote>(add custom fields to the bug page)</span>
<p>
<li class=listitem><a target=_blank href=query.aspx>run ad-hoc query</a>
&nbsp;&nbsp;
<span style="border: solid red 1px; padding: 2px; margin: 3px; xbackground: yellow; color: red; font-size: 9px;">
This links to query.aspx.&nbsp;&nbsp;Query.aspx is not safe on a public web server.&nbsp;&nbsp;Delete it if you are deploying on a public web server.</span><br>
<p>
<li class=listitem><a href=notifications.aspx>queued email notifications</a>
</ul>
</td></tr></table>

<p>&nbsp;<p>
<table border=0><tr><td>
	<div style="padding: 15px; font-size: 11pt; border: 2px dotted red; background: #eeffee;">
	Control other important options by editing the file "Web.config" in the IIS virtual directory.
	<p>
	<a target="_blank" style="font-size: 11pt;" href="view_web_config.aspx">View Web.config file</a>
	</div>
</td></tr></table>
<p>&nbsp;<p>
<p>Server Info:
<%
Response.Write ("<br>Path=");
Response.Write (HttpContext.Current.Server.MapPath(null));
Response.Write ("<br>MachineName=");
Response.Write (HttpContext.Current.Server.MachineName);
Response.Write ("<br>ScriptTimeout=");
Response.Write (HttpContext.Current.Server.ScriptTimeout);
Response.Write ("<br>.NET Version=");
Response.Write(Environment.Version.ToString());

%>

</div>
<% Response.Write(Application["custom_footer"]); %></body>
</html>