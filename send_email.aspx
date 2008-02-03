<%@ Page language="C#" validateRequest="false" %>
<%@ Register TagPrefix="FCKeditorV2" Namespace="FredCK.FCKeditorV2" Assembly="FredCK.FCKeditorV2" %>
<%@ Import Namespace="System.IO" %>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

// disable System.Net.Mail warnings
#pragma warning disable 618
#warning System.Web.Mail is obsolete, but System.Net.Mail doesn't seem to work with GMail, so keeping System.Web.Mail for now - corey
    
String sql;
DbUtil dbutil;
Security security;
int project = -1;


///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	btnet.Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK);


	titl.InnerText = btnet.Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ "send email";

	fckeBody.BasePath = @"fckeditor/";
	fckeBody.ToolbarSet = "BugTracker";

	msg.InnerText = "";

	string string_bp_id = Request["bp_id"];
	string string_bg_id = Request["bg_id"];
	string request_to = Request["to"];
	string request_from = Request["from"];
	string reply = Request["reply"];


	if (security.user.use_fckeditor)
	{
		fckeBody.Visible = true;
		body.Visible = false;
	}
	else
	{
	    fckeBody.Visible = false;
		body.Visible = true;
	}

	if (!IsPostBack)
	{

		DataRow dr = null;

		if (string_bp_id != null)
		{

			string_bp_id = btnet.Util.sanitize_integer(string_bp_id);

			sql = @"select
				bp_parent,
                bp_file,
                bp_id,
				bg_id,
				bg_short_desc,
				bp_email_from,
				bp_comment,
				bp_email_from,
				bp_date,
				bp_type,
                bp_content_type,
				bg_project,
				isnull(us_signature,'') [us_signature],
				isnull(pj_pop3_email_from,'') [pj_pop3_email_from],
				isnull(us_email,'') [us_email]
				from bug_posts
				inner join bugs on bp_bug = bg_id
				inner join users on us_id = $us
				left outer join projects on bg_project = pj_id
				where bp_id = $id
				or (bp_parent = $id and bp_type='file')";

			sql = sql.Replace("$id", string_bp_id);
			sql = sql.Replace("$us", Convert.ToString(security.user.usid));

            DataView dv = dbutil.get_dataview(sql);
            dr = null;
            if (dv.Count > 0)
            {
                dv.RowFilter = "bp_id = " + string_bp_id;
                if (dv.Count > 0)
                {
                    dr = dv[0].Row;
                }
            }

			string_bg_id = Convert.ToString(dr["bg_id"]);
			back_href.HRef = "edit_bug.aspx?id=" + string_bg_id;
			bg_id.Value = string_bg_id;

			if (request_to != null)
			{
				to.Value = request_to;
			}
			else
			{
				to.Value = dr["bp_email_from"].ToString();
			}


			// format from dropdown
			if (request_from != null)
			{
				from.Items.Add(new ListItem(request_from));
			}
			if (dr["pj_pop3_email_from"].ToString() != "")
			{
				from.Items.Add(new ListItem(dr["pj_pop3_email_from"].ToString()));
			}
			if (dr["us_email"].ToString() != "")
			{
				from.Items.Add(new ListItem(dr["us_email"].ToString()));
			}
			if (from.Items.Count == 0)
			{
				from.Items.Add(new ListItem("[none]"));
			}

			if (reply != null && reply == "all")
			{
				Regex regex = new Regex("\n");
				string[] lines = regex.Split((string) dr["bp_comment"]);
				string cc_addrs = "";

				int max = lines.Length < 5 ? lines.Length : 5;

				// gather cc addresses, which might include the current user
				for (int i = 0; i < max; i++)
				{
					if (lines[i].StartsWith("To:") || lines[i].StartsWith("Cc:"))
					{
						string cc_addr = lines[i].Substring(3, lines[i].Length - 3).Trim();

						// don't cc yourself

						if (cc_addr.IndexOf(from.SelectedItem.Value) == -1)
						{
							if (cc_addrs != "")
							{
								cc_addrs += ",";
							}

							cc_addrs += cc_addr;
						}
					}
				}

				cc.Value = cc_addrs;
			}

			if (dr["us_signature"].ToString() != "")
			{
				if (security.user.use_fckeditor)
				{
				    fckeBody.Value += "<br><br><br>";
					fckeBody.Value += dr["us_signature"].ToString().Replace("\r\n", "<br>");
					fckeBody.Value += "<br><br><br>";
				}
				else
				{
					body.Value += "\n\n\n";
					body.Value += dr["us_signature"].ToString();
					body.Value += "\n\n\n";
				}
			}


			if (Request["quote"] != null)
			{
				Regex regex = new Regex("\n");
				string[] lines = regex.Split((string) dr["bp_comment"]);

				if (dr["bp_type"].ToString() == "received")
				{
					if (security.user.use_fckeditor)
					{
					    fckeBody.Value += "&#62;From: " + dr["bp_email_from"].ToString().Replace("<", "&#60;").Replace(">", "&#62;") + "<br>";
					}
					else
					{
						body.Value += ">From: " + dr["bp_email_from"] + "\n";
					}
				}

				for (int i = 0; i < lines.Length; i++)
				{
					if (lines[i].IndexOf("To:") == 0 && i < 3)
					{
						if (security.user.use_fckeditor)
						{
                            fckeBody.Value += "&#62;" + lines[i].Replace("<", "&#60;").Replace(">", "&#62;") + "<br>";
							fckeBody.Value += "&#62;Date: " + Convert.ToString(dr["bp_date"]) + "<br>&#62;<br>";
						}
						else
						{
							body.Value += ">" + lines[i] + "\n";
							body.Value += ">Date: " + Convert.ToString(dr["bp_date"]) + "\n>\n";
						}
					}
					else
					{
						if (security.user.use_fckeditor)
						{
                            if (Convert.ToString(dr["bp_content_type"]) != "text/html")
                            {
							fckeBody.Value += "&#62;" + lines[i].Replace("<", "&#60;").Replace(">", "&#62;") + "<br>";
						}
						else
						{
                                if (i == 0)
                                {
                                    fckeBody.Value += "<hr>";
                                }
                                fckeBody.Value += lines[i];
                            }
						}
						else
						{
							body.Value += ">" + lines[i] + "\n";
						}
					}
				}
			}

			if (reply == "forward")
            {
                to.Value = "";
                //original attachments
                //dv.RowFilter = "bp_parent = " + string_bp_id;
                dv.RowFilter = "bp_type = 'file'";
                foreach (DataRowView drv in dv)
                {
                    attachments_label.InnerText = "Select attachments to forward:";
                    lstAttachments.Items.Add(new ListItem(drv["bp_file"].ToString(), drv["bp_id"].ToString()));
                }

			}

		}
		else if (string_bg_id != null)
		{

			string_bg_id = btnet.Util.sanitize_integer(string_bg_id);

			int permission_level = btnet.Bug.get_bug_permission_level(Convert.ToInt32(string_bg_id), security);
			if (permission_level == Security.PERMISSION_NONE
			|| permission_level == Security.PERMISSION_READONLY)
			{
				Response.Write("You are not allowed to edit this item");
				Response.End();
			}

			sql = @"select
				bg_short_desc,
				bg_project,
				isnull(us_signature,'') [us_signature],
				isnull(us_email,'') [us_email],
				isnull(pj_pop3_email_from,'') [pj_pop3_email_from]
				from bugs
				inner join users on us_id = $us
				left outer join projects on bg_project = pj_id
				where bg_id = $bg";

			sql = sql.Replace("$us", Convert.ToString(security.user.usid));
			sql = sql.Replace("$bg", string_bg_id);

			dr = dbutil.get_datarow(sql);

			// format from dropdown
			if (request_from != null)
			{
				from.Items.Add(new ListItem(request_from));
			}
			if (dr["us_email"].ToString() != "")
			{
				from.Items.Add(new ListItem(dr["us_email"].ToString()));
			}
			if (dr["pj_pop3_email_from"].ToString() != "")
			{
				from.Items.Add(new ListItem(dr["pj_pop3_email_from"].ToString()));
			}
			if (from.Items.Count == 0)
			{
				from.Items.Add(new ListItem("[none]"));
			}


			back_href.HRef = "edit_bug.aspx?id=" + string_bg_id;
			bg_id.Value = string_bg_id;

			if (request_to != null)
			{
				to.Value = request_to;
			}

			if (dr["us_signature"].ToString() != "")
			{
				if (security.user.use_fckeditor)
				{
				    fckeBody.Value += "<br><br><br>";
					fckeBody.Value += dr["us_signature"].ToString().Replace("\r\n", "<br>");
				}
				else
				{
					body.Value += "\n\n\n";
					body.Value += dr["us_signature"].ToString();
				}
			}


		}

		if (string_bp_id != null || string_bg_id != null)
		{

			subject.Value = (string) dr["bg_short_desc"]
				+ "  (" + btnet.Util.get_setting("TrackingIdString","DO NOT EDIT THIS:")
				+ bg_id.Value
				+ ")";

			// for determining which users to show in "address book"
			project = (int) dr["bg_project"];

		}

	}



}


///////////////////////////////////////////////////////////////////////
bool validate()
{

	Boolean good = true;


	if (to.Value == "")
	{
		good = false;
		to_err.InnerText = "\"To\" is required.";
	}
	else
	{
		to_err.InnerText = "";
	}

	if (from.SelectedItem.Value == "[none]")
	{
		good = false;
		from_err.InnerText = "\"From\" is required.  Go to settings";
	}
	else
	{
		from_err.InnerText = "";
	}

	if (subject.Value == "")
	{
		good = false;
		subject_err.InnerText = "\"Subject\" is required.";
	}
	else
	{
		subject_err.InnerText = "";
	}

	msg.InnerText = "Email was not sent.";

	return good;

}

///////////////////////////////////////////////////////////////////////
string get_bug_text(int bugid)
{
		// Get bug html

		DataRow bug_dr = btnet.Bug.get_bug_datarow(bugid, security);

		// Create a fake response and let the code
		// write the html to that response
		System.IO.StringWriter writer = new System.IO.StringWriter();
		HttpResponse my_response = new HttpResponse(writer);
		PrintBug.print_bug(my_response, bug_dr, security.user.is_admin, security.user.external_user);
		return writer.ToString();
}

///////////////////////////////////////////////////////////////////////
void on_update(object Source, EventArgs e)
{

	if (!validate()) return;

	sql = @"insert into bug_posts
			(bp_bug, bp_user, bp_date, bp_comment, bp_comment_search, bp_email_from, bp_email_to, bp_type, bp_content_type)
			values($id, $us, getdate(), N'$cm', N'$cs', N'$fr',  N'$to', 'sent', N'$ct')
			select scope_identity()";

	sql = sql.Replace("$id", bg_id.Value);
	sql = sql.Replace("$us", Convert.ToString(security.user.usid));
	if (security.user.use_fckeditor)
	{
		sql = sql.Replace("$cm", fckeBody.Value.Replace("'", "&#39;"));
		sql = sql.Replace("$cs", btnet.Util.strip_html(fckeBody.Value).Replace("'", "''"));
		sql = sql.Replace("$ct", "text/html");
	}
	else
	{
	sql = sql.Replace("$cm", HttpUtility.HtmlDecode(body.Value.Replace("'", "''")));
		sql = sql.Replace("$cs", body.Value.Replace("'", "''"));
		sql = sql.Replace("$ct", "text/plain");
	}
	sql = sql.Replace("$fr", from.SelectedItem.Value.Replace("'", "''"));
	sql = sql.Replace("$to", to.Value.Replace("'","''"));

	int comment_id = Convert.ToInt32(dbutil.execute_scalar(sql));

	int[] attachments = handle_attachments(comment_id);

	string body_text;
	System.Web.Mail.MailFormat format;
	System.Web.Mail.MailPriority priority;

	switch (prior.SelectedItem.Value) {
		case "High":
			priority = System.Web.Mail.MailPriority.High;
			break;
		case "Low":
			priority = System.Web.Mail.MailPriority.Low;
			break;
		default:
			priority = System.Web.Mail.MailPriority.Normal;
			break;
	}

	if (include_bug_cb.Checked)
	{

		// white space isn't handled well, I guess.
		if (security.user.use_fckeditor)
		{
		    body_text = fckeBody.Value;
			body_text  += "<br><br>";
		}
		else
		{
			body_text = body.Value.Replace("\n","<br>");
			body_text = body_text.Replace("\t","&nbsp;&nbsp;&nbsp;&nbsp;");
			body_text = body_text.Replace("  ","&nbsp; ");
		}
		body_text += "<hr>" + get_bug_text(Convert.ToInt32(bg_id.Value));

		format = System.Web.Mail.MailFormat.Html;
	}
	else
	{
		if (security.user.use_fckeditor)
		{
		    body_text = fckeBody.Value;
			format = System.Web.Mail.MailFormat.Html;
		}
		else
		{
			body_text = HttpUtility.HtmlDecode(body.Value);
			//body_text = body_text.Replace("\n","\r\n");
			format = System.Web.Mail.MailFormat.Text;
		}
	}

	string result = btnet.Email.send_email( // 9 args
		to.Value,
		from.SelectedItem.Value,
		cc.Value,
		subject.Value,
		body_text,
		format,
		priority,
		attachments,
		return_receipt.Checked);

	btnet.Bug.send_notifications(btnet.Bug.UPDATE, Convert.ToInt32(bg_id.Value), security);

	if (result == "")
	{
		Response.Redirect("edit_bug.aspx?id=" + bg_id.Value);
	}
	else
	{
		msg.InnerText = result;
	}

}


///////////////////////////////////////////////////////////////////////
int[] handle_attachments(int comment_id)
{
    ArrayList attachments = new ArrayList();

    string filename = System.IO.Path.GetFileName(attached_file.PostedFile.FileName);
    if (filename != "")
    {
        //add attachment
		int max_upload_size = Convert.ToInt32(btnet.Util.get_setting("MaxUploadSize","100000"));
		int content_length = attached_file.PostedFile.ContentLength;
		if (content_length > max_upload_size)
		{
			msg.InnerText = "File exceeds maximum allowed length of "
			+ Convert.ToString(max_upload_size)
			+ ".";
			return null;
		}

		if (content_length == 0)
		{
			msg.InnerText = "No data was uploaded.";
			return null;
		}

        int bp_id = Bug.insert_post_attachment(security, Convert.ToInt32(bg_id.Value), attached_file.PostedFile.InputStream, content_length, filename, "email attachment", file_extension_to_content_type(Path.GetExtension(filename)), comment_id, false, false);
        attachments.Add(bp_id);
	}

    //attachments to forward

    foreach (ListItem item_attachment in lstAttachments.Items)
	{
        if (item_attachment.Selected)
        {
            int bp_id = Convert.ToInt32(item_attachment.Value);

            Bug.insert_post_attachment_copy(security, Convert.ToInt32(bg_id.Value), bp_id, "email attachment", comment_id, false, false);
            attachments.Add(bp_id);
        }
    }

    return (int[])attachments.ToArray(typeof(int));
}

///////////////////////////////////////////////////////////////////////
string file_extension_to_content_type(string ext)
{
	if (ext == ".jpg"
	|| ext == ".jpeg")
	{
		return "image/jpg";
	}
	else if (ext == ".gif")
	{
		return "image/gif";
	}
	else if (ext == ".bmp")
	{
		return "image/bmp";
	}
	else if (ext == ".txt")
	{
		return "text/plain";
	}
	else if (ext == ".doc")
	{
		return "application/msword";
	}
	else if (ext == ".xls")
	{
		return "application/excel";
	}
	else if (ext == ".zip")
	{
		return "application/zip";
	}
	else if (ext == ".htm"
	|| ext == ".html"
	|| ext == ".asp"
	|| ext == ".aspx"
	|| ext == ".php")
	{
		return "text/html";
	}
	else
	{
		return "";
	}
}

///////////////////////////////////////////////////////////////////////
int save_attachment(int comment_id, string filename, int content_length, string ext)
{
	sql = @"insert into bug_posts
			(bp_type, bp_bug, bp_file, bp_comment, bp_size, bp_date, bp_user, bp_parent, bp_content_type)
			values ('file', $1, N'$2', N'$3', $4, getdate(), $5, $6, '$7')
			select scope_identity()";

	sql = sql.Replace("$1", bg_id.Value);
	sql = sql.Replace("$2", filename.Replace("'","''"));
	sql = sql.Replace("$3", "email attachment");
	sql = sql.Replace("$4", Convert.ToString(content_length));
	sql = sql.Replace("$5", Convert.ToString(security.user.usid));
	sql = sql.Replace("$6", Convert.ToString(comment_id));
	sql = sql.Replace("$7", file_extension_to_content_type(ext));

	// save the attachment's identity
	return Convert.ToInt32(dbutil.execute_scalar(sql));
}


</script>

<html>
<head>
<title id="titl" runat="server">btnet send email</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">

<script>

var hidden_button;
var addr_target

function show_addrs(button, targ)
{
	addr_target = document.getElementById(targ);
	var addrs = document.getElementById("addrs");
	addrs.style.left = findPosX(button);
	addrs.style.top = findPosY(button);
	// hide the button
	hidden_button = button;
	hidden_button.style.display = "none";
	addrs.style.display = "block";
}

function hide_addrs()
{
	var addrs = document.getElementById("addrs");
	addrs.style.display = "none";
	hidden_button.style.display = ""
}

function select_addrs(sel)
{
	if (addr_target.value != "")
	{
		addr_target.value += ",";
	}
	addr_target.value += sel.options[sel.selectedIndex].text
}

function findPosX(obj)
{
	var curleft = 0;
	if (obj.offsetParent)
	{
		while (obj.offsetParent)
		{
			curleft += obj.offsetLeft
			obj = obj.offsetParent;
		}
	}
	else if (obj.x)
		curleft += obj.x;
	return curleft;
}

function findPosY(obj)
{
	var curtop = 0;
	if (obj.offsetParent)
	{
		while (obj.offsetParent)
		{
			curtop += obj.offsetTop
			obj = obj.offsetParent;
		}
	}
	else if (obj.y)
		curtop += obj.y;
	return curtop;
}

</script>


</head>
<body>
<% security.write_menu(Response, btnet.Util.get_setting("PluralBugLabel","bugs")); %>
<div class=align><table border=0><tr><td>

<a id="back_href" runat="server" href="">back to <% Response.Write(btnet.Util.get_setting("SingularBugLabel","bug")); %></a>

<form class=frm runat="server" enctype="multipart/form-data">
	<table border=0>

	<tr>
	<td class=lbl>To:</td>
	<td><input runat="server" type=text class=txt id="to" maxlength=800 size=80>
	<input type=button value="..." onclick="show_addrs(this, 'to')" >
	</td>
	<td runat="server" class=err id="to_err">&nbsp;</td>
	</tr>

	<tr>
	<td class=lbl>From:</td>

    <td>
	<asp:DropDownList id="from" runat="server">
	</asp:DropDownList>
	</td>

	<td runat="server" class=err id="from_err">&nbsp;</td>
	</tr>


	<tr>
	<td class=lbl>CC:</td>
	<td><input runat="server" type=text class=txt id="cc" size=80>
	<input type=button value="..." onclick="show_addrs(this, 'cc')" >
	</td>

	<td runat="server" class=err id="cc_err">&nbsp;</td>
	</tr>

	<tr>
	<td class=lbl>Subject:</td>
	<td><input runat="server" type=text class=txt id="subject" size=80></td>
	<td runat="server" class=err id="subject_err">&nbsp;</td>
	</tr>

	<tr>
	<td class=lbl>Attachment:</td>
	<td><input runat="server" type=file class=txt id="attached_file" maxlength=255 size=60></td>
	<td runat="server" class=err id="attached_file_err">&nbsp;</td>
	</tr>

	<tr>
    <td class="lbl" runat="server" id="attachments_label"></td>
    <td><asp:CheckBoxList id="lstAttachments" runat="server"></asp:CheckBoxList></td>
    <td></td>
    </tr>

	<tr>
	<td class=lbl>Priority:</td>
	<td>

	<asp:DropDownList id="prior" runat="server">
		<asp:ListItem Value="High" Text="High"/>
	    <asp:ListItem Selected="True" Value="Normal" Text="Normal"/>
	    <asp:ListItem Value="Low" Text="Low"/>
	</asp:DropDownList>

	</td>
	<td>&nbsp;</td>
	</tr>

	<tr>
	<td colspan=2><input runat="server" type=checkbox class=txt id="return_receipt" >Return receipt</td>
	</tr>

	<tr>
	<td colspan=2><input runat="server" type=checkbox class=txt id="include_bug_cb" >Include print of <% Response.Write(btnet.Util.get_setting("SingularBugLabel","Bug")); %></td>
	</tr>


	<tr>
	<td colspan=3>
	<textarea rows=15 cols=72 runat="server" class=txt id="body"></textarea>
	<FCKeditorV2:FCKeditor id="fckeBody" runat="server" Width="700px" Height="300px"></FCKeditorV2:FCKeditor>
	</td>
	</tr>

	<tr><td colspan=3 align=left>
	<span runat="server" class=err id="msg">&nbsp;</span>
	</td></tr>

	<tr>
	<td colspan=2 align=center>
	<input runat="server" class=btn type=submit id="sub" value="Send" OnServerClick="on_update">
	</td>
	<td>&nbsp;</td>
	</tr>
    </table>
	<input type=hidden id="bg_id" runat="server">
</form>
</table>
</div>

<div id=addrs class=frm style="display: none; position:absolute;">

	Click to select recipient:&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;

	<a style="position: absolute; right: 0px; margin-right: 5px; " href="javascript:hide_addrs()">close</a>

	<div style="width: 250px;">&nbsp;</div>
	<select id=addrs_select size=6 onchange="select_addrs(this)">
	<%

	// fill re-assign dropdown
	if (project > -1)
	{
		if (project == 0)
		{

			sql = @"select us_email
				from users
				where us_active = 1
				and len(us_email) > 0
				order by us_email";

		}
		else
		{
			// Only users explicitly allowed will be listed
			if (btnet.Util.get_setting("DefaultPermissionLevel","2") == "0")
			{
				sql = @"select us_email
					from users
					where us_active = 1
					and len(us_email) > 0
					and us_id in
						(select pu_user from project_user_xref
						where pu_project = $pr
						and pu_permission_level <> 0)
					order by us_email";
			}
			// Only users explictly DISallowed will be omitted
			else
			{
				sql = @"select us_email
					from users
					where us_active = 1
					and len(us_email) > 0
					and us_id not in
						(select pu_user from project_user_xref
						where pu_project = $pr
						and pu_permission_level = 0)
					order by us_email";
			}
		}

		sql = sql.Replace("$pr", Convert.ToString(project));
		DataSet ds_emails = dbutil.get_dataset(sql);
		foreach (DataRow dr_email in ds_emails.Tables[0].Rows)
		{
			Response.Write("<option>");
			Response.Write(dr_email["us_email"]);
			Response.Write("</option>");
		}

	}

	%>

	</select>
</div>

<% Response.Write(Application["custom_footer"]); %></body>
</html>
