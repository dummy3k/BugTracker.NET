<%@ Page language="C#"%>
<%@ Import Namespace="System.IO" %>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

int bugid;
DbUtil dbutil;
Security security;
int added_attachment = 0;

void Page_Init (object sender, EventArgs e) {ViewStateUserKey = Session.SessionID;}


///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK);

	added_attachment = 0;

	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ "add attachment";

	msg.InnerText = "";

	string string_id = Util.sanitize_integer(Request.QueryString["id"]);
//	back_href.HRef = "edit_bug.aspx?id=" + string_id;

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


	if (security.user.external_user || Util.get_setting("EnableInternalOnlyPosts","0") == "0")
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

	try
	{
        Bug.insert_post_attachment(
            security,
			bugid,
			attached_file.PostedFile.InputStream,
			content_length,
			filename,
			desc.Value,
			attached_file.PostedFile.ContentType,
			-1, // parent
			internal_only.Checked,
			true);

		added_attachment = 1;

	}
	catch (Exception ex)
	{
		msg.InnerText = ex.Message;
		return;
	}

	//Response.Redirect ("edit_bug.aspx?id=" + Convert.ToString(bugid), false);
}


</script>

<html>
<head>
<title id="titl" runat="server">btnet add attachment</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>

<script>

function body_on_load()
{

	opener.maybe_rewrite_posts(
	<%
		Response.Write(Convert.ToString(bugid));
		Response.Write(",");
		Response.Write(added_attachment);
	%>
	)

}

</script>


<body onload="body_on_load()">

<div class=align>

Add attachment to <% Response.Write(Convert.ToString(bugid)); %>
<p>
	<table border=0><tr><td>
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
			<input runat="server" class=btn type=submit id="sub" value="Upload" onserverclick="on_update">
			</td>
			</tr>
			</table>
		</form>
	</td></tr></table>
</div>
<% Response.Write(Application["custom_footer"]); %></body>
</html>