<%@ Page language="C#"%>
<!--
Copyright 2002-2007 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->
<!-- #include file = "inc_logon.inc" -->

<script language="C#" runat="server">


DbUtil dbutil;
string sql;

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.set_context(HttpContext.Current);

	Util.do_not_cache(Response);

	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ "logon";

	app.InnerText = Util.get_setting("AppTitle","BugTracker.NET");

	msg.InnerText = "";

	// see if the connection string works
	try
	{
		dbutil = new DbUtil();
		dbutil.get_sqlconnection();

		try
		{
			dbutil.execute_nonquery("select count(1) from users");

		}
		catch (SqlException e1)
		{
			Util.write_to_log (e1.Message);
			Util.write_to_log (Util.get_setting("ConnectionString","?"));
			msg.InnerHtml = "Unable to find \"bugs\" table.<br>"
			+ "Click to <a href=install.aspx>setup database tables</a>";
		}

	}
	catch (SqlException e2)
	{
		msg.InnerHtml = "Unable to connect.<br>"
		+ e2.Message + "<br>"
		+ "Check Web.config file \"ConnectionString\" setting.<br>"
		+ "Check also <a href=http://sourceforge.net/forum/forum.php?forum_id=226938>Help Forum</a> on Sourceforge.";
	}

	// If an error occured, then force the authentication to manual
	if (Request.QueryString["msg"] != null)
	{
		msg.InnerHtml = Request.QueryString["msg"];
	}

}

///////////////////////////////////////////////////////////////////////
void on_logon(Object sender, EventArgs e)
{


	sql = @"select us_id, us_username
		from users
		where us_username = N'$us'
		and (us_password = N'$pw' or us_password = N'$en')
		and us_active = 1";

	sql = sql.Replace("$us", user.Value.Replace("'","''"));
	if (pw.Value.Length == 32)
	{
		sql = sql.Replace("$pw", "");
	}
	else
	{
		sql = sql.Replace("$pw", pw.Value.Replace("'","''"));
	}

	sql = sql.Replace("$en", Util.encrypt_string_using_MD5(pw.Value));

	DataRow dr = dbutil.get_datarow(sql);
	if (dr != null)
	{
		int userid = (int) dr["us_id"];

		create_session (
			userid,
			(string) dr["us_username"],
			"0");

		Response.Redirect ("bugs.aspx");

	}
	else
	{
		msg.InnerText = "Invalid User or Password.";
	}

}

</script>

<html>
<head>
<title id="titl" runat="server">btnet logon</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body onload="document.forms[0].user.focus()">
<table border=0><tr>

<%

string logo = Util.get_setting("LogoHtml","");

if (logo == "")
{

%>

<td width=100 valign=middle>
<a href=http://btnet.sourceforge.net>
	<div class=logo id=app runat="server">BugTracker.NET</div>
</a>

<%
}
else
{
	Response.Write(logo);
}

%>

</table>

<div align="center">
<table border=0><tr><td>
<form class=frm runat="server">
	<table border=0>

	<tr>
	<td class=lbl>User:</td>
	<td><input runat="server" type=text class=txt id="user"></td>
	</tr>

	<tr>
	<td class=lbl>Password:</td>
	<td><input runat="server" type=password class=txt id="pw"></td>
	</tr>

	<tr><td colspan=2 align=left>
	<span runat="server" class=err id="msg">&nbsp;</span>
	</td></tr>

	<tr><td colspan=2 align=center>
	<input class=btn type=submit value="Logon" OnServerClick="on_logon"  runat="server">
	</td></tr>

	</table>

</form>
</td></tr></table>
</div>
</body>
</html>