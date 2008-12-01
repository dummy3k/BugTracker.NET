<%@ Page language="C#" validateRequest="false" %>
<%@ Register TagPrefix="FCKeditorV2" Namespace="FredCK.FCKeditorV2" Assembly="FredCK.FCKeditorV2" %>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

int id;
String sql;


Security security;

bool use_fckeditor = false;
int bugid;

void Page_Init (object sender, EventArgs e) {ViewStateUserKey = Session.SessionID;}


///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	btnet.Util.do_not_cache(Response);
	
	security = new Security();

	security.check_security( HttpContext.Current, Security.ANY_USER_OK_EXCEPT_GUEST);

	if (security.user.is_admin || security.user.can_edit_and_delete_posts)
	{
		//
	}
	else
	{
		Response.Write ("You are not allowed to use this page.");
		Response.End();
	}

	titl.InnerText = btnet.Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ "edit comment";

	msg.InnerText = "";

	id = Convert.ToInt32(Request["id"]);

	if (!IsPostBack)
	{
        sql = @"select bp_comment, bp_type,
        isnull(bp_comment_search,bp_comment) bp_comment_search,
        isnull(bp_content_type,'') bp_content_type,
        bp_bug, bp_hidden_from_external_users
        from bug_posts where bp_id = $id";
	}
	else
	{
        sql = @"select bp_bug, bp_type,
        isnull(bp_content_type,'') bp_content_type,
        bp_hidden_from_external_users
        from bug_posts where bp_id = $id";
	}

	sql = sql.Replace("$id", Convert.ToString(id));
	DataRow dr = btnet.DbUtil.get_datarow(sql);

	bugid = (int) dr["bp_bug"];

	int permission_level = btnet.Bug.get_bug_permission_level(bugid, security);
	if (permission_level == Security.PERMISSION_NONE
	|| permission_level == Security.PERMISSION_READONLY
	|| (string) dr["bp_type"] != "comment")
	{
		Response.Write("You are not allowed to edit this item");
		Response.End();
	}

	string content_type = (string)dr["bp_content_type"];

	if (content_type == "text/html" &&  btnet.Util.get_setting("DisableFCKEditor","0") == "0")
	{
		use_fckeditor = true;
		fckeComment.Visible = true;
		comment.Visible = false;
		fckeComment.BasePath = @"fckeditor/";
		fckeComment.ToolbarSet = "BugTracker";
	}
	else
	{
		use_fckeditor = false;
		fckeComment.Visible = false;
		comment.Visible = true;
	}

	if (security.user.external_user || btnet.Util.get_setting("EnableInternalOnlyPosts","0") == "0")
	{
		internal_only.Visible = false;
		internal_only_label.Visible = false;
	}

	if (!IsPostBack)
	{
		internal_only.Checked = Convert.ToBoolean((int) dr["bp_hidden_from_external_users"]);

		if (content_type == "text/html")
		{
 			if (btnet.Util.get_setting("DisableFCKEditor","0") == "1")
 			{
 				comment.Value = (string) dr["bp_comment_search"];
			}
			else
			{
       			fckeComment.Value = (string)dr["bp_comment"];
			}
		}
		else
		{
			comment.Value = (string) dr["bp_comment"];
		}
	}


}


///////////////////////////////////////////////////////////////////////
Boolean validate()
{

	Boolean good = true;

	if (comment.Value.Length == 0 && fckeComment.Value.Length == 0)
	{
		msg.InnerText = "Comment cannot be blank.";
		return false;
	}

	return good;
}

///////////////////////////////////////////////////////////////////////
void on_update (Object sender, EventArgs e)
{

	Boolean good = validate();

	if (good)
	{

		sql = @"update bug_posts set
                    bp_comment = N'$cm',
                    bp_comment_search = N'$cs',
                    bp_content_type = N'$cn',
                    bp_hidden_from_external_users = $internal
                where bp_id = $id

                select bg_short_desc from bugs where bg_id = $bugid";

        if (use_fckeditor)
		{
            string text = btnet.Util.strip_dangerous_tags(fckeComment.Value);
            sql = sql.Replace("$cm", text.Replace("'", "&#39;"));
            sql = sql.Replace("$cs", btnet.Util.strip_html(fckeComment.Value).Replace("'", "''"));
            sql = sql.Replace("$cn", "text/html");
		}
		else
		{
            // Oops! This is backwards, but don't change it now!
            if (btnet.Util.get_setting("HtmlDecodeComment", "1") == "1")
            {
                sql = sql.Replace("$cm", comment.Value.Replace("'", "''"));
            }
            else
            {
                sql = sql.Replace("$cm", HttpUtility.HtmlDecode(comment.Value).Replace("'", "''"));
			}
            sql = sql.Replace("$cs", comment.Value.Replace("'", "''"));
            sql = sql.Replace("$cn", "text/plain");
		}

		sql = sql.Replace("$id", Convert.ToString(id));
		sql = sql.Replace("$bugid", Convert.ToString(bugid));
		sql = sql.Replace("$internal", btnet.Util.bool_to_string(internal_only.Checked));
		DataRow dr = btnet.DbUtil.get_datarow(sql);

		// Don't send notifications for internal only comments.
		// We aren't putting them the email notifications because it that makes it
		// easier for them to accidently get forwarded to the "wrong" people...
		if (!internal_only.Checked)
		{
			btnet.Bug.send_notifications(btnet.Bug.UPDATE, bugid, security);
			btnet.WhatsNew.add_news(bugid, (string) dr["bg_short_desc"], "updated", security);
		}

		Response.Redirect ("edit_bug.aspx?id=" + Request["bug_id"]);

	}

}

</script>

<html>
<head>
<title id="titl" runat="server">btnet edit comment</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body>
<% security.write_menu(Response, btnet.Util.get_setting("PluralBugLabel","bugs")); %>


<div class=align>
<table border=0><tr><td>

<a href=edit_bug.aspx?id=<% Response.Write(Request["bug_id"]);%>>back to <% Response.Write(btnet.Util.get_setting("SingularBugLabel","bug")); %></a>
<form class=frm runat="server">

	<table border=0>
		<tr>
		<td colspan=3>
		<textarea rows=16 cols=80 runat="server" class=txt id="comment"></textarea>
		<FCKeditorV2:FCKeditor id="fckeComment" runat="server" Width="700px" Height="400px"></FCKeditorV2:FCKeditor>

		<tr>
		<td colspan=3>
		<asp:checkbox runat="server" class=cb id="internal_only"/>
		<span runat="server" id="internal_only_label">Visible to internal users only</span>
		</td>
		</tr>

		<tr><td colspan=3 align=left>
		<span runat="server" class=err id="msg">&nbsp;</span>

		<tr>
		<td colspan=2 align=center>
		<input runat="server" class=btn type=submit id="sub" value="Update" OnServerClick="on_update">

	</table>
</form>
</td></tr></table></div>
<% Response.Write(Application["custom_footer"]); %></body>
</html>


