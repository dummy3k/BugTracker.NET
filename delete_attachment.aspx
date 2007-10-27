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

	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK_EXCEPT_GUEST);

	if (security.this_is_admin || security.this_can_edit_and_delete_posts)
	{
		//
	}
	else
	{
		Response.Write ("You are not allowed to use this page.");
		Response.End();
	}

	string attachment_id_string = Util.sanitize_integer(Request["id"]);
	string bug_id_string = Util.sanitize_integer(Request["bug_id"]);
	string confirm = Request.QueryString["confirm"];

	int permission_level = btnet.Bug.get_bug_permission_level(Convert.ToInt32(bug_id_string), security);
	if (permission_level != Security.PERMISSION_ALL)
	{
		Response.Write("You are not allowed to edit this item");
		Response.End();
	}


	if (confirm == "y")
	{
		// save the filename before deleting the row
		sql = @"select bp_file from bug_posts where bp_id = $ba";
		sql = sql.Replace("$ba", attachment_id_string);
		string filename = (string) dbutil.execute_scalar(sql);

		// delete the row representing the attachment
		sql = @"delete bug_posts where bp_id = $ba";
		sql = sql.Replace("$ba", attachment_id_string);
		dbutil.execute_nonquery(sql);

		// delete the file too
		string upload_folder = Util.get_upload_folder();
		StringBuilder path = new StringBuilder(upload_folder);
		path.Append("\\");
		path.Append(bug_id_string);
		path.Append("_");
		path.Append(attachment_id_string);
		path.Append("_");
		path.Append(filename);
		if (System.IO.File.Exists(path.ToString()))
		{
			System.IO.File.Delete(path.ToString());
		}


		Response.Redirect("edit_bug.aspx?id=" + bug_id_string);
	}
	else
	{
		back_href.HRef =
			"edit_bug.aspx?id=" + bug_id_string;

		confirm_href.HRef =
			"delete_attachment.aspx?confirm=y&id=" 	+ attachment_id_string
			+ "&bug_id=" + bug_id_string;


		sql = @"select bp_file from bug_posts where bp_id = $1";
		sql = sql.Replace("$1", attachment_id_string);

		DataRow dr = dbutil.get_datarow(sql);

		string s = Convert.ToString(dr["bp_file"]);

		confirm_href.InnerText = "confirm delete of attachment: " + s;


	}

}


</script>

<html>
<head>
<title id="titl" runat="server">btnet delete attachment</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body>
<% security.write_menu(Response, Util.get_setting("PluralBugLabel","bugs")); %>
<p>
<div class=align>

<p>&nbsp</p>
<a id="back_href" runat="server" href="">
back to <% Response.Write(Util.get_setting("SingularBugLabel","bug")); %>
</a>

<p>
or
<p>
<a id="confirm_href" runat="server" href="">confirm delete</a>
</div>
</body>
</html>


