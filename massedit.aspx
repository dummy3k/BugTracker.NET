<%@ Page language="C#"%>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

String sql;
DbUtil dbutil;
Security security;

void Page_Init (object sender, EventArgs e) {ViewStateUserKey = Session.SessionID;}

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();

	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK_EXCEPT_GUEST);

	if (security.user.is_admin || security.user.can_mass_edit_bugs)
	{
		//
	}
	else
	{
		Response.Write ("You are not allowed to use this page.");
		Response.End();
	}


	string list = "";

	if (!IsPostBack)
	{
		titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
			+ "massedit";

		if (Request["mass_delete"] != null)
		{
			update_or_delete.Value = "delete";
		}
		else
		{
			update_or_delete.Value = "update";
		}

		// create list of bugs affected
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

		bug_list.Value = list;

		if (update_or_delete.Value == "delete")
		{
			update_or_delete.Value = "delete";

			sql += "delete bug_post_attachments from bug_post_attachments inner join bug_posts on bug_post_attachments.bpa_post = bug_posts.bp_id where bug_posts.bp_bug in (" + list + ")";
			sql += "\ndelete from bug_posts where bp_bug in (" + list + ")";
			sql += "\ndelete from bug_subscriptions where bs_bug in (" + list + ")";
			sql += "\ndelete from bug_relationships where re_bug1 in (" + list + ")";
			sql += "\ndelete from bug_relationships where re_bug2 in (" + list + ")";
			sql += "\ndelete from bugs where bg_id in (" + list + ")";

			confirm_href.InnerText = "Confirm Delete";

		}
		else
		{
			update_or_delete.Value = "update";

			sql = "update bugs \nset ";

			string updates = "";

			string project = Request["mass_project"];
			if (project != "-1" && Util.is_int(project))
			{
				if (updates != "") {updates += ",\n";}
				updates += "bg_project = " + project;
			}
			string org = Request["mass_org"];
			if (org!= "-1" && Util.is_int(org))
			{
				if (updates != "") {updates += ",\n";}
				updates += "bg_org = " + org;
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

		sql_text.InnerText = sql;

	}
	else // postback
	{
		list = bug_list.Value;

		if (update_or_delete.Value == "delete")
		{
			string upload_folder = Util.get_upload_folder();
			if (upload_folder != null)
			{
				string sql2 = @"select bp_bug, bp_id, bp_file from bug_posts where bp_type = 'file' and bp_bug in (" + bug_list.Value + ")";
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
		}


		dbutil.execute_nonquery(sql_text.InnerText);
		Response.Redirect ("search.aspx");

	}
}


</script>
<html>
<head>
<title id="titl" runat="server">btnet mass edit</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body>

<% security.write_menu(Response, "admin"); %>
<div class=align>

	<p>
	<div runat="server" id=msg class=err>&nbsp;</div>

	<p>
	<a href="search.aspx">back to search</a>

<p>or<p>
<script>
function submit_form()
{
	var frm = document.getElementById("frm");
	frm.submit();
	return true;
}

</script>
<form runat="server" id="frm">
<a style="border: 1px red solid; padding: 3px;" id="confirm_href" runat="server" href="javascript: submit_form()"></a>
<input type="hidden" id="bug_list" runat="server">
<input type="hidden" id="update_or_delete" runat="server">
</form>


	<p>&nbsp;<p>
	<p><div class=err>Email notifications are not sent when updates are made via this page.</div>
	<p>This SQL statement will execute when you confirm:
	<pre id="sql_text" runat="server"></pre>

</div>
<% Response.Write(Application["custom_footer"]); %></body>
</html>

