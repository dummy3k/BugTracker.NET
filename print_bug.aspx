<%@ Page language="C#"%>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

DbUtil dbutil;
Security security;

DataRow dr;

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK);

	string string_bugid = Request.QueryString["id"];

	int bugid = Convert.ToInt32(string_bugid);

	dr = btnet.Bug.get_bug_datarow(bugid, security);

	if (dr == null)
	{
		Response.Write ("<link rel=StyleSheet href=btnet.css type=text/css>");
		security.write_menu(Response, Util.get_setting("PluralBugLabel","bugs"));
		Response.Write("<p>&nbsp;</p><div class=align>");
		Response.Write("<div class=err>");
		Response.Write(Util.capitalize_first_letter(Util.get_setting("SingularBugLabel","bug")));
		Response.Write(" not found:&nbsp;" + string_bugid + "</div>");
		Response.Write("<p><a href=bugs.aspx>View ");
		Response.Write(Util.get_setting("PluralBugLabel","bugs"));
		Response.Write("</a>");
		Response.End();
	}



	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ Util.capitalize_first_letter(Util.get_setting("SingularBugLabel","bug"))
		+  " ID" + string_bugid + " " + (string) dr["short_desc"];


	// don't allow user to view a bug he is not allowed to view
	if ((int)dr["pu_permission_level"] == 0)
	{
		Response.Write ("<link rel=StyleSheet href=btnet.css type=text/css>");
		security.write_menu(Response, Util.get_setting("PluralBugLabel","bugs"));
		Response.Write("<p>&nbsp;</p><div class=align>");
		Response.Write("<div class=err>You are not allowed to view this bug</div>");
		Response.Write("<p><a href=bugs.aspx>View Bugs</a>");
		Response.End();
	}


}


</script>

<html>
<head>
<title  id="titl" runat="server">btnet edit bug</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
<style>
a {text-decoration: underline; }
a:visited {text-decoration: underline; }
a:hover {text-decoration: underline; }
</style>

</head>

<% PrintBug.print_bug(Response, dr, security, false /* include style */); %>

</html>


