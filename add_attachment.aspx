<%@ Page language="C#"%>
<!--
Copyright 2002-2007 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

int bugid;
String sql;
DbUtil dbutil;
Security security;


///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK);


	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ "add attachment";

	msg.InnerText = "";

	string string_id = Util.sanitize_integer(Request.QueryString["id"]);
	back_href.HRef = "edit_bug.aspx?id=" + string_id;

	if (string_id == null || string_id == "0")
	{
		Response.Write ("Invalid id.");
		Response.End();
	}
	else
	{
		bugid = Convert.ToInt32(string_id);
		int permission_level = Bug.get_bug_permission_level(bugid, security);
		if (permission_level == Security.PERMISSION_NONE
		|| permission_level == Security.PERMISSION_READONLY)
		{
			Response.Write("You are not allowed to edit this item");
			Response.End();
		}
	}


	if (security.this_external_user || Util.get_setting("EnableInternalOnlyPosts","0") == "0")
	{
		internal_only.Visible = false;
		internal_only_label.Visible = false;
	}
}

void on_update(object Source, EventArgs e)
{

	if (attached_file.PostedFile == null)
	{
		msg.InnerText = "Please select file.";
		return;
	}

	string filename = System.IO.Path.GetFileName(attached_file.PostedFile.FileName);
	if (filename == "")
	{
		msg.InnerText = "Please select file.";
		return;
	}

	int max_upload_size = Convert.ToInt32(Util.get_setting("MaxUploadSize","100000"));
	int content_length = attached_file.PostedFile.ContentLength;
	if (content_length > max_upload_size)
	{
		msg.InnerText = "File exceeds maximum allowed length of "
			+ Convert.ToString(max_upload_size)
			+ ".";
		return;
	}

	if (content_length == 0)
	{
		msg.InnerText = "No data was uploaded.";
		return;
	}

	string upload_folder;
	try
	{
		upload_folder = Util.get_upload_folder();
	}
	catch (Exception ex)
	{
		msg.InnerText = ex.Message;
		return;
	}



	sql = @"insert into bug_posts
			(bp_type, bp_bug, bp_file, bp_comment, bp_size, bp_date, bp_user, bp_content_type, bp_hidden_from_external_users)
			values ('file', $bg, N'$fi', N'$de', $si, getdate(), $us, N'$ct', $internal)
			select scope_identity()";

	sql = sql.Replace("$bg", Convert.ToString(bugid));
	sql = sql.Replace("$fi", filename.Replace("'","''"));
	sql = sql.Replace("$de", desc.Value.Replace("'", "''"));
	sql = sql.Replace("$si", Convert.ToString(content_length));
	sql = sql.Replace("$us", Convert.ToString(security.this_usid));
	sql = sql.Replace("$ct", attached_file.PostedFile.ContentType);
	sql = sql.Replace("$internal", btnet.Util.bool_to_string(internal_only.Checked));


	// save the attachment's identity

	int bp_id = Convert.ToInt32(dbutil.execute_scalar(sql));

	try
	{

		attached_file.PostedFile.SaveAs(
			upload_folder + "\\"
			+ bugid + "_"      // bug id
			+ bp_id + "_"   // attachment id
			+ filename);

		if (!internal_only.Checked)
		{
			btnet.Bug.send_notifications(btnet.Bug.UPDATE, bugid, security.this_usid, security.this_is_admin);
		}

		Response.Redirect ("edit_bug.aspx?id=" + Convert.ToString(bugid), false);

	}
	catch (Exception e2)
	{

		// clean up
		sql = @"delete from bug_posts where bp_id = $bp";

		sql = sql.Replace("$bp",Convert.ToString(bp_id));

		dbutil.execute_nonquery(sql);

		msg.InnerText = e2.Message;
		return;
	}
}


</script>

<html>
<head>
<title id="titl" runat="server">btnet add attachment</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body>

<% security.write_menu(Response, Util.get_setting("PluralBugLabel","bugs")); %>
<div class=align><table border=0><tr><td>

<a id="back_href" runat="server" href="">back to <% Response.Write(Util.get_setting("SingularBugLabel","bug")); %></a>

<form class=frm runat="server" enctype="multipart/form-data" action="add_attachment.aspx">
	<table border=0>

	<tr>
	<td class=lbl>Description:</td>
	<td><input runat="server" type=text class=txt id="desc" maxlength=80 size=80></td>
	<td runat="server" class=err id="desc_err">&nbsp;</td>
	</tr>

	<tr>
	<td class=lbl>File:</td>
	<td><input runat="server" type=file class=txt id="attached_file" maxlength=255 size=60></td>
	<td runat="server" class=err id="attached_file_err">&nbsp;</td>
	</tr>

	<tr>
	<td colspan=3>
	<asp:checkbox runat="server" class=txt id="internal_only"/>
	<span runat="server" id="internal_only_label">Visible to internal users only</span>
	</td>
	</tr>

	<tr><td colspan=3 align=left>
	<span runat="server" class=err id="msg">&nbsp;</span>
	</td></tr>

	<tr>
	<td colspan=2 align=center>
	<input runat="server" class=btn type=submit id="sub" value="Upload" OnServerClick="on_update">
	<td>&nbsp</td>
	</td>
	</tr>
	</td></tr></table>
</form>
</td></tr></table></div>
</body>
</html>