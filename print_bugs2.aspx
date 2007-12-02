<%@ Page language="C#"%>
<!--
Copyright 2002-2007 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">


String sql;

DbUtil dbutil;
Security security;

DataSet ds = null;
DataView dv = null;

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK);

	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ "print " + Util.get_setting("PluralBugLabel","bugs");


	// are we doing the query to get the bugs or are we using the cached dataview?
	string qu_id_string = Request.QueryString["qu_id"];

	if (qu_id_string != null)
	{

		// use sql specified in query string
		int qu_id = Convert.ToInt32(qu_id_string);
		sql = @"select qu_sql from queries where qu_id = $1";
		sql = sql.Replace("$1", qu_id_string);
		string bug_sql = (string)dbutil.execute_scalar(sql);

		// replace magic variables
		bug_sql = bug_sql.Replace("$ME", Convert.ToString(security.this_usid));
		bug_sql = Util.alter_sql_per_project_permissions(bug_sql,security);

		// all we really need is the bugid, but let's do the same query as print_bugs.aspx
		ds = dbutil.get_dataset (bug_sql);
	}
	else
	{
		dv = (DataView) Session["bugs"];
	}

}


</script>

<html>
<head>
<title id="titl" runat="server">btnet print bugs detail</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>

<%

bool firstrow = true;

if (dv != null)
{
	foreach (DataRowView drv in dv)
	{
		if (!firstrow)
		{
			Response.Write ("<hr STYLE='page-break-before: always'>");
		}
		else
		{
			firstrow = false;
		}

		DataRow dr = btnet.Bug.get_bug_datarow(
			(int)drv[1],
			security);

		PrintBug.print_bug(Response, dr, security.this_is_admin, security.this_external_user);
	}
}
else
{
	if (ds != null)
	{
		foreach (DataRow dr2 in ds.Tables[0].Rows)
		{
			if (!firstrow)
			{
				Response.Write ("<hr STYLE='page-break-before: always'>");
			}
			else
			{
				firstrow = false;
			}

			DataRow dr = btnet.Bug.get_bug_datarow(
				(int)dr2[1],
				security);

			PrintBug.print_bug(Response, dr, security.this_is_admin, security.this_external_user);
		}
	}
	else
	{
		Response.Write ("Please recreate the list before trying to print...");
		Response.End();
	}
}

%>

</html>


