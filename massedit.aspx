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

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.MUST_BE_ADMIN);

	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ "massedit";

	// create list of bugs affected
	string list = "";
	foreach (string var in Request.QueryString)
	{
		if (Util.is_int(var))
		{
			if (list != "")
			{
				list += ",";
			}
			list += var;
		};
	}

	// handle NO BUGS SELECTED
	if (list == "")
	{
		msg.InnerText = "No items selected!";
	}
	else
	{
		// create the SQL

		if (Request["mass_delete"] != null)
		{

			sql = "delete from bug_posts where bp_bug in (" + list + ")";
			sql += "\ndelete from bug_subscriptions where bs_bug in (" + list + ")";
			sql += "\ndelete from bug_relationships where re_bug1 in (" + list + ")";
			sql += "\ndelete from bug_relationships where re_bug2 in (" + list + ")";
			sql += "\ndelete from bugs where bg_id in (" + list + ")";

			confirm_href.InnerText = "Confirm Delete";
		}
		else
		{
			sql = "update bugs \nset ";

			string updates = "";

			string project = Request["mass_project"];
			if (project != "-1" && Util.is_int(project))
			{
				if (updates != "") {updates += ",\n";}
				updates += "bg_project = " + project;
			}

			string category = Request["mass_category"];
			if (category != "-1" && Util.is_int(category))
			{
				if (updates != "") {updates += ",\n";}
				updates += "bg_category = " + category;
			}

			string priority = Request["mass_priority"];
			if (priority != "-1" && Util.is_int(priority))
			{
				if (updates != "") {updates += ",\n";}
				updates += "bg_priority = " + priority;
			}

			string assigned_to = Request["mass_assigned_to"];
			if (assigned_to != "-1" && Util.is_int(assigned_to))
			{
				if (updates != "") {updates += ",\n";}
				updates += "bg_assigned_to_user = " + assigned_to;
			}

			string status = Request["mass_status"];
			if (status != "-1" && Util.is_int(status))
			{
				if (updates != "") {updates += ",\n";}
				updates += "bg_status = " + status;
			}


			sql += updates + "\nwhere bg_id in (" + list + ")";
			confirm_href.InnerText = "Confirm Update";
		}


		// either run the sql, or just ask for confirmation
		if (Request["confirm"] != null)
		{
			if (Request["mass_delete"] != null)
			{
				string upload_folder = Util.get_upload_folder();
				string sql2 = @"select bp_bug, bp_id, bp_file from bug_posts where bp_type = 'file' and bp_bug in (" + list + ")";
				DataSet ds = dbutil.get_dataset(sql2);
				foreach (DataRow dr in ds.Tables[0].Rows)
				{
					// create path
					StringBuilder path = new StringBuilder(upload_folder);
					path.Append("\\");
					path.Append(Convert.ToString(dr["bp_bug"]));
					path.Append("_");
					path.Append(Convert.ToString(dr["bp_id"]));
					path.Append("_");
					path.Append(Convert.ToString(dr["bp_file"]));
					if (System.IO.File.Exists(path.ToString()))
					{
						System.IO.File.Delete(path.ToString());
					}
				}
			}
			dbutil.execute_nonquery(sql);
			Response.Redirect ("search.aspx");
		}
		else
		{
			sql_text.InnerText = sql;
			confirm_href.HRef = "massedit.aspx?confirm=y&" + Request.QueryString;
		}

	}

}


</script>
<html>
<head>
<title id="titl" runat="server">btnet edit category</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body>

<% security.write_menu(Response, "admin"); %>
<div class=align>

	<p>
	<div runat="server" id=msg class=err>&nbsp;</div>

	<p>
	<a href="search.aspx">back to search</a>

	<p>
	<a id="confirm_href" runat="server" href=""></a>

	<hr>
	<p><div class=err>Email notifications are not sent when updates are made via this page.</div>
	<p>SQL statement:
	<pre id="sql_text" runat="server"></pre>

</div>
</body>
</html>

