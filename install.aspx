<%@ Page language="C#"%>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);

	if (Request["dbname"] != null && Request["dbname"] != "")
	{
		DbUtil dbutil = new DbUtil();
		dbutil.get_sqlconnection();
		string sql = @"use master
			create database [$db]";

		sql = sql.Replace("$db", Request["dbname"]);
		dbutil.execute_nonquery(sql);

		Response.Write ("<font color=red><b>Database Created.</b></font>");

	}


}

</script>


<html>
<head>
<title id="titl" runat="server">btnet install</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body>
<p>
<b>How to get BugTracker.NET up and running</b>
<p>
1) Create a SQL Server database.    You can use the form below.
<p>
2) Update the database connection string in Web.config to point to your database.
<p>
3) Copy/paste the text in the file <a target=_blank href=setup.sql>"setup.sql"</a> into <a target=_blank href=query.aspx>this form</a> and run it.
<p>
4) Logon at <a href=default.aspx>default.aspx</a> using user "admin" and password "admin"
<p>
You probably should spend time looking at the README.HTML and Web.config files.   If you have any questions, post them to the <a href=http://sourceforge.net/forum/forum.php?forum_id=226938>Help Forum</a>.

<hr>
<form action=install.aspx method=get>
Database Name:&nbsp;<input name=dbname>
<br>
<input type=submit value="Create Database">
</form>

</body>
</html>