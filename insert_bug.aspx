<%@ Page language="C#" validateRequest="false"%>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Text.RegularExpressions" %>
<%@ Import Namespace="anmar.SharpMimeTools" %>
<%@ Assembly Name="SharpMimeTools" %>

<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">



Security security;
String sql;

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.set_context(HttpContext.Current);
	Util.do_not_cache(Response);
	

	string username = Request["username"];
	string password = Request["password"];
	string projectid_string = Request["projectid"];
	string comment = Request["comment"];
	string from = Request["from"];
	string cc = "";
	string message = Request["message"];
	string attachment_as_base64 = Request["attachment"];
	string attachment_content_type = Request["attachment_content_type"];
	string attachment_filename = Request["attachment_filename"];
	string attachment_desc = Request["attachment_desc"];

	// only via emails
	if (from == null)
	{
		from = "";
	}
	else if (from.Length > 100)
	{
		from = from.Substring(0,100);
	}

	// this could also be the email subject
	string short_desc = (Request["short_desc"]);
	if (short_desc == null)
	{
		short_desc = "";
	}
	else if (short_desc.Length > 200)
	{
		short_desc = short_desc.Substring(0,200);
	}

	SharpMimeMessage mime_message = null;

	if (message != null && message.Length > 0)
	{
		// feed a stream to MIME parser
		byte[] bytes = Encoding.UTF8.GetBytes(message);
		System.IO.MemoryStream ms = new System.IO.MemoryStream (bytes);
		mime_message = new SharpMimeMessage(ms);

		if (mime_message.Header.ContentType.ToLower().IndexOf("text/plain") > -1
		&& !is_attachment(mime_message))
		{
			comment = mime_message.BodyDecoded;
		}
		else
		{
			comment = extract_comment_text_from_email(mime_message, "text/plain");
			if (comment == null)
			{
				comment = extract_comment_text_from_email(mime_message, "text/html");
			}

			if (comment == null)
			{
				comment = "NO PLAIN TEXT MESSAGE BODY FOUND";
			}
		}
	}
	else
	{
		if (comment == null)
		{
			comment = "";
		}
	}


	string bugid_string = Request["bugid"];

	if (username == null
	|| username == "")
	{
		Response.AddHeader("BTNET","ERROR: username required");
		Response.Write("ERROR: username required");
		Response.End();
	}

	if (password == null
	|| password == "")
	{
		Response.AddHeader("BTNET","ERROR: password required");
		Response.Write("ERROR: password required");
		Response.End();
	}

	// authenticate user

    bool authenticated = btnet.Authenticate.check_password(username, password);

    if (!authenticated)
    {
		Response.AddHeader("BTNET","ERROR: invalid username or password");
		Response.Write("ERROR: invalid username or password");
		Response.End();
    }

    sql = @"select us_id, us_admin, us_org, og_other_orgs_permission_level
		from users
		inner join orgs on us_org = og_id
		where us_username = N'$us'";

	sql = sql.Replace("$us",username.Replace("'","''"));

	DataRow dr = btnet.DbUtil.get_datarow(sql);

    // this should never happen
    if (dr == null)
	{
		Response.AddHeader("BTNET","ERROR: authenticated user, but no user in db?");
		Response.Write("ERROR: authenticated user, but no user in db?");
		Response.End();
	}

	security = new Security();
	security.context = HttpContext.Current;
	security.user.username = from;
	security.user.usid = (int) dr["us_id"];
	security.user.is_admin = Convert.ToBoolean(dr["us_admin"]);
	security.user.org = (int) dr["us_org"];
	security.user.other_orgs_permission_level = (int) dr["og_other_orgs_permission_level"];

	int projectid = 0;
	if (Util.is_int(projectid_string))
	{
		projectid = Convert.ToInt32(projectid_string);
	}

	int bugid = 0;

	if (Util.is_int(bugid_string))
	{
		bugid = Convert.ToInt32(bugid_string);
	}


	// Even though btnet_service.exe has already parsed out the bugid,
	// we can do a better job here with SharpMimeTools.dll
	string subject = "";

	if (mime_message != null)
	{
		if (mime_message.Header.Subject != null && mime_message.Header.Subject != "")
		{
			subject = SharpMimeTools.parserfc2047Header(mime_message.Header.Subject);

			// handle multiline subject
			subject = subject.Replace("\t","");

			// Try to parse out the bugid from the subject line
			string bugidString=Util.get_setting("TrackingIdString","DO NOT EDIT THIS:");

			int pos = subject.IndexOf(bugidString);

			if (pos >= 0)
			{
				// position of colon
				pos=subject.IndexOf(":",pos);
				pos++;

				// position of close paren
				int pos2=subject.IndexOf(")",pos);
				if (pos2 > pos)
				{
					string bugid_string_temp = subject.Substring(pos,pos2-pos);
					if (Util.is_int(bugid_string_temp))
					{
						bugid = Convert.ToInt32(bugid_string_temp);
					}
				}
			}
		}
		else
		{
			subject = "[No Subject]";
		}


		if (mime_message.Header.Cc != null && mime_message.Header.Cc != "")
		{
			cc = SharpMimeTools.parserfc2047Header(mime_message.Header.Cc);

			// handle multiline
			cc = cc.Replace("\t","");

		}

	}

	if (bugid != 0)
	{
		// Check if the bug is still in the database
		// No comment can be added to merged or deleted bugids
		// In this case a new bug is created, this to prevent possible loss of information

		sql = @"select count(bg_id)
			from bugs
			where bg_id = $id";

		sql = sql.Replace("$id", Convert.ToString(bugid));

		if (Convert.ToInt32(btnet.DbUtil.execute_scalar(sql)) == 0)
		{
			bugid = 0;
		}
	}


	// Either insert a new bug or append a commment to existing bug
	// based on presence, absence of bugid
	if (bugid == 0)
	{
		// insert a new bug

		string email_to = "";

		if (mime_message != null)
		{

			// in case somebody is replying to a bug that has been deleted or merged
			subject = subject.Replace(Util.get_setting("TrackingIdString","DO NOT EDIT THIS:"), "PREVIOUS:");

			short_desc = subject;
			if (short_desc.Length > 200)
			{
				short_desc = short_desc.Substring(0,200);
			}

			string headers = get_headers_for_comment(mime_message);


			if (headers != "")
			{
				comment = headers + "\n" + comment;
			}
		}

		int orgid = 0;
		int categoryid = 0;
		int priorityid = 0;
		int assignedid = 0;
		int statusid = 0;
		int udfid = 0;

		bool ProcessVariablesInEmails = (Util.get_setting("ProcessVariablesInEmails","0") == "1");

		/*

		Two different ways of changing category, etc.   Using query string variables and using
		some magic in the body of the email.

		*/

		if (ProcessVariablesInEmails) // use this setting even for the query string variables
		{
			if (Request["$ORGANIZATION$"] != null && Request["$ORGANIZATION$"] != "") {orgid = Convert.ToInt32(Request["$ORGANIZATION$"]);}
			if (Request["$CATEGORY$"] != null && Request["$CATEGORY$"] != "") {categoryid = Convert.ToInt32(Request["$CATEGORY$"]);}
			if (Request["$PRIORITY$"] != null && Request["$PRIORITY$"] != "") {priorityid = Convert.ToInt32(Request["$PRIORITY$"]);}
			if (Request["$ASSIGNEDTO$"] != null && Request["$ASSIGNEDTO$"] != "") {assignedid = Convert.ToInt32(Request["$ASSIGNEDTO$"]);}
			if (Request["$STATUS$"] != null && Request["$STATUS$"] != "") {statusid = Convert.ToInt32(Request["$STATUS$"]);}
			if (Request["$UDF$"] != null && Request["$UDF$"] != "") {udfid = Convert.ToInt32(Request["$UDF$"]);}
		}

		Regex regex = new Regex("\r\n");
		string[] lines = regex.Split(comment);
		string adjusted_comment = "";

		// loop through the messages
		for (int i=0;i < lines.Length; i++)
		{
			if (ProcessVariablesInEmails)
			{
				if (lines[i].IndexOf("$ORGANIZATION$:") > -1)
				{
					try
					{
						orgid = Convert.ToInt32(lines[i].Substring(lines[i].IndexOf("$ORGANIZATION$:") + 15));
					}
					catch (Exception)
					{
					}
				}
				else if (lines[i].IndexOf("$CATEGORY$:") > -1)
				{
					try
					{
						categoryid = Convert.ToInt32(lines[i].Substring(lines[i].IndexOf("$CATEGORY$:") + 11));
					}
					catch (Exception)
					{
					}
				}
				else if (lines[i].IndexOf("$PRIORITY$:") > -1)
				{
					try
					{
						priorityid = Convert.ToInt32(lines[i].Substring(lines[i].IndexOf("$PRIORITY$:") + 11));
					}
					catch (Exception)
					{
					}
				}
				else if (lines[i].IndexOf("$ASSIGNEDTO$:") > -1)
				{
					try
					{
						assignedid = Convert.ToInt32(lines[i].Substring(lines[i].IndexOf("$ASSIGNEDTO$:") + 13));
					}
					catch (Exception)
					{
					}
				}
				else if (lines[i].IndexOf("$STATUS$:") > -1)
				{
					try
					{
						statusid = Convert.ToInt32(lines[i].Substring(lines[i].IndexOf("$STATUS$:") + 9));
					}
					catch (Exception)
					{
					}
				}
				else if (lines[i].IndexOf("$PROJECT$:") > -1)
				{
					try
					{
						projectid = Convert.ToInt32(lines[i].Substring(lines[i].IndexOf("$PROJECT$:") + 10));
					}
					catch (Exception)
					{
					}
				}
				else if (lines[i].IndexOf("$UDF$:") > -1)
				{
					try
					{
						udfid = Convert.ToInt32(lines[i].Substring(lines[i].IndexOf("$UDF$:") + 6));
					}
					catch (Exception)
					{
					}
				}
				else
				{
					if (adjusted_comment != "")
					{
						adjusted_comment += "\r\n";
					}
					adjusted_comment += lines[i];
				}
			}
			else
			{
				if (adjusted_comment != "")
				{
					adjusted_comment += "\r\n";
				}
				adjusted_comment += lines[i];
			}
		}

		sql = @"declare @pj int
		declare @ct int
		declare @pr int
		declare @st int
		declare @udf int
		set @pj = 0
		set @ct = 0
		set @pr = 0
		set @st = 0
		set @udf = 0
		select @pj = pj_id from projects where pj_default = 1 order by pj_name
		select @ct = ct_id from categories where ct_default = 1 order by ct_name
		select @pr = pr_id from priorities where pr_default = 1 order by pr_name
		select @st = st_id from statuses where st_default = 1 order by st_name
		select @udf = udf_id from user_defined_attribute where udf_default = 1 order by udf_name
		select @pj pj, @ct ct, @pr pr, @st st, @udf udf";

		DataRow defaults = btnet.DbUtil.get_datarow(sql);

		if (projectid == 0) {projectid = (int) defaults["pj"];}
		if (orgid == 0) {orgid = security.user.org;}
		if (categoryid == 0) {categoryid = (int) defaults["ct"];}
		if (priorityid == 0) {priorityid = (int) defaults["pr"];}
		if (statusid == 0) {statusid = (int) defaults["st"];}
		if (udfid == 0) {udfid = (int) defaults["udf"];}


		btnet.Bug.NewIds new_ids = btnet.Bug.insert_bug(
			short_desc,
			security,
            "", // tags
			projectid,
			orgid,
			categoryid,
			priorityid,
			statusid,
			assignedid,
			udfid,
			"","","", // project specific dropdown values
			adjusted_comment,
            adjusted_comment,
			from,
			cc,
			"text/plain",
			false, // internal only
			null, // custom columns
            false);  // suppress notifications for now - wait till after the attachments

		if (mime_message != null)
		{
			add_attachments(mime_message, new_ids.bugid, new_ids.postid);

			string auto_reply_text = Util.get_setting("AutoReplyText","");
			auto_reply_text = auto_reply_text.Replace("$BUGID$", Convert.ToString(new_ids.bugid));

			if (auto_reply_text != "")
			{
				// to prevent endless loop of replies when "from" email happens to be the
				// same as the "to" email, make sure that condition isn't true
				if (from.ToUpper() != email_to.ToUpper())
				{

					// Get the project from e-mail
					string to;

					sql = @"select
						pj_pop3_email_from
						from projects
						where pj_id = $pj";

					sql = sql.Replace("$pj", Convert.ToString(projectid));

					object project_email = btnet.DbUtil.execute_scalar(sql);

					if (project_email != null)
					{
						to = Convert.ToString(project_email);
					}
					else
					{
						to = email_to;
					}

					string outgoing_subject = short_desc + "  ("
					+ Util.get_setting("TrackingIdString","DO NOT EDIT THIS:")
					+ new_ids.bugid + ")";

					btnet.Email.send_email( // 4 args
						from, // we are responding to the from
						to,
						"",
						outgoing_subject,
						auto_reply_text);

				}
			}
		}
		else if (attachment_as_base64 != null && attachment_as_base64.Length > 0)
		{

			if (attachment_desc == null) attachment_desc = "";
			if (attachment_content_type == null) attachment_content_type = "";
			if (attachment_filename == null) attachment_filename = "";

			System.Byte[] byte_array = System.Convert.FromBase64String(attachment_as_base64);
			Stream stream = new MemoryStream(byte_array);

			Bug.insert_post_attachment(
				security,
				new_ids.bugid,
				stream,
				byte_array.Length,
				attachment_filename,
				attachment_desc,
				attachment_content_type,
				-1, // parent
				false, // internal_only
				false); // don't send notification yet
		}


        btnet.Bug.send_notifications(btnet.Bug.INSERT, new_ids.bugid, security);
        btnet.WhatsNew.add_news(new_ids.bugid, short_desc, "added", security);

		Response.AddHeader("BTNET","OK:" + Convert.ToString(new_ids.bugid));
		Response.Write ("OK:" + Convert.ToString(new_ids.bugid));
		Response.End();

	}
	else // update existing bug
	{

		string StatusResultingFromIncomingEmail = Util.get_setting("StatusResultingFromIncomingEmail","0");

		sql = "";

		if (StatusResultingFromIncomingEmail != "0")
		{

			sql = @"update bugs
				set bg_status = $st
				where bg_id = $bg
				";

				sql = sql.Replace("$st", StatusResultingFromIncomingEmail);

		}

		sql += "select bg_short_desc from bugs where bg_id = $bg";

		sql = sql.Replace("$bg", Convert.ToString(bugid));
		DataRow dr2 = btnet.DbUtil.get_datarow(sql);

		if (mime_message != null)
		{

			string headers = get_headers_for_comment(mime_message);

			if (headers != "")
			{
				comment = headers + "\n" + comment;
			}
		}

		// Add a comment to existing bug.
		int postid = btnet.Bug.insert_comment(
            bugid,
			(int) dr["us_id"],
		 	comment,
            comment,
		 	from,
		 	cc,
		 	"text/plain",
		 	false); // internal only

		if (mime_message != null)
		{
			add_attachments(mime_message, bugid, postid);
		}
		else if (attachment_as_base64 != null && attachment_as_base64.Length > 0)
		{

			if (attachment_desc == null) attachment_desc = "";
			if (attachment_content_type == null) attachment_content_type = "";
			if (attachment_filename == null) attachment_filename = "";

			System.Byte[] byte_array = System.Convert.FromBase64String(attachment_as_base64);
			Stream stream = new MemoryStream(byte_array);

			Bug.insert_post_attachment(
				security,
				bugid,
				stream,
				byte_array.Length,
				attachment_filename,
				attachment_desc,
				attachment_content_type,
				-1, // parent
				false, // internal_only
				false); // don't send notification yet
		}

		btnet.Bug.send_notifications(btnet.Bug.UPDATE, bugid, security);
		btnet.WhatsNew.add_news(bugid, (string) dr2["bg_short_desc"], "updated", security);

		Response.AddHeader("BTNET","OK:" + Convert.ToString(bugid));
		Response.Write ("OK:" + Convert.ToString(bugid));

		Response.End();
	}

}

///////////////////////////////////////////////////////////////////////
string extract_comment_text_from_email(SharpMimeMessage mime_message, string mimetype)
{


	string comment = null;

	// use the first plain text message body
	foreach (SharpMimeMessage part in mime_message)
	{


		if (part.IsMultipart)
		{
			foreach (SharpMimeMessage subpart in part)
			{

				if (subpart.IsMultipart)
				{
					foreach (SharpMimeMessage sub2 in subpart)
					{
						if (sub2.Header.ContentType.ToLower().IndexOf(mimetype) > -1
						&& !is_attachment(sub2))
						{
							comment = sub2.BodyDecoded;
							break;
						}
					}
				}
				else
				{
					if (subpart.Header.ContentType.ToLower().IndexOf(mimetype) > -1
					&& !is_attachment(subpart))
					{
						comment = subpart.BodyDecoded;
						break;
					}
				}
			}
		}
		else
		{
			if (part.Header.ContentType.ToLower().IndexOf(mimetype) > -1
			&& !is_attachment(part))
			{
				comment = part.BodyDecoded;
				break;
			}
		}
	}


	return comment;
}


///////////////////////////////////////////////////////////////////////
bool is_attachment(SharpMimeMessage part)
{
	string filename = part.Header.ContentDispositionParameters["filename"];
	if (string.IsNullOrEmpty(filename))
	{
		filename = part.Header.ContentTypeParameters["name"];
	}

	if (filename != null && filename != "")
	{
		return true;
	}
	else
	{
		return false;
	}
}

///////////////////////////////////////////////////////////////////////
string determine_part_filename(SharpMimeMessage part)
{


	string filename = "";

	filename = part.Header.ContentDispositionParameters["filename"];


	// try again
	if (string.IsNullOrEmpty(filename))
	{
		filename = part.Header.ContentTypeParameters["name"];
	}


	// Maybe it's still some sort of non-text part but without a filename.
	// Like an inline image, or the html alternative of a plain text body.
	if (string.IsNullOrEmpty(filename))
	{

		if (part.Header.ContentType.ToLower().IndexOf("text/plain") > -1)
		{
			// The plain text body.  We don't want to
			// add this as an attachment.

		}
		else
		{

			// Some other mime part we don't understand.
			// Let's make it an attachment with a synthesized filename, just so we don't loose it.

			// Change text/html to text.html, etc
			// so that downstream logic that reacts
			// to the file extensions works.
			filename = part.Header.ContentType;
			filename = filename.Replace("/",".");
			int pos = filename.IndexOf(";");
			if (pos > 0)
			{
				filename = filename.Substring(0,pos);
			}
		}
	}

	if (filename == null)
	{
		filename = "";
	}

	return filename;

}

///////////////////////////////////////////////////////////////////////
void add_attachments(SharpMimeMessage mime_message, int bugid, int parent_postid)
{
	if (mime_message.IsMultipart)
	{
		foreach (SharpMimeMessage part in mime_message)
		{
			if (part.IsMultipart)
			{
				// recursive call to this function
				add_attachments(part, bugid, parent_postid);
			}
			else
			{

				string filename = determine_part_filename(part);

				if (filename != "")
				{
					add_attachment(filename, part, bugid, parent_postid);
				}
			}
		}
	}

	else
	{
		string filename = determine_part_filename(mime_message);

		if (filename != "")
		{
			add_attachment(filename, mime_message, bugid, parent_postid);
		}
	}

}

///////////////////////////////////////////////////////////////////////

void add_attachment(string filename, SharpMimeMessage part, int bugid, int parent_postid)
{

	Util.write_to_log("attachment:" + filename);

	string missing_attachment_msg = "";

	int max_upload_size = Convert.ToInt32(Util.get_setting("MaxUploadSize","100000"));
	if (part.Size > max_upload_size)
	{
		missing_attachment_msg = "ERROR: email attachment exceeds size limit.";
	}

	string content_type = part.Header.TopLevelMediaType + "/" + part.Header.SubType;
    string desc;
    MemoryStream attachmentStream = new MemoryStream();

    if (missing_attachment_msg == "")
		{
        desc = "email attachment";
		}
    else
		{
        desc = missing_attachment_msg;
	}
    part.DumpBody(attachmentStream);
    attachmentStream.Position = 0;
    Bug.insert_post_attachment(
        security,
        bugid,
        attachmentStream,
        (int)attachmentStream.Length,
        filename,
        desc,
        content_type,
        parent_postid,
        false,  // not hidden
        false); // don't send notifications

	sql = @"insert into bug_posts
			(bp_type, bp_bug, bp_file, bp_comment, bp_size, bp_date, bp_user, bp_content_type, bp_parent)
			values ('file', $bg, N'$fi', N'$de', $si, getdate(), $us, N'$ct', $pp)
			select scope_identity()";
}


///////////////////////////////////////////////////////////////////////
string get_headers_for_comment(SharpMimeMessage mime_message)
{
    string headers = "";
    
    if (mime_message.Header.Subject != null && mime_message.Header.Subject != "")
	{
        headers = "Subject: " + mime_message.Header.Subject + "\n";
	}

	if (mime_message.Header.To != null && mime_message.Header.To != "")
	{
		headers += "To: " + mime_message.Header.To + "\n";
	}

	if (mime_message.Header.Cc != null && mime_message.Header.Cc != "")
	{
		headers += "Cc: " + mime_message.Header.Cc + "\n";
	}

    return headers;
}


</script>