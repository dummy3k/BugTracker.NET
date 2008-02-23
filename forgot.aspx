<%@ Page language="C#"%>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

DbUtil dbutil;


///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.set_context(HttpContext.Current);
	Util.do_not_cache(Response);

	if (Util.get_setting("AllowSelfRegistration","0") == "0")
	{
		Response.Write("Sorry, Web.config AllowSelfRegistration is set to 0");
		Response.End();
	}

	if (!IsPostBack)
	{
		titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
			+ "forgot password";
	}
	else
	{
		msg.InnerHtml = "";

		if (email.Value == "")
		{
			msg.InnerHtml = "Enter your email address.";
		}
		else if (!Util.validate_email(email.Value))
		{
			msg.InnerHtml = "Format of email address is invalid.";
		}
		else
		{

			dbutil = new DbUtil();

			// check if email exists
			int user_count = (int) dbutil.execute_scalar(
				"select count(1) from users where us_email = N'" + email.Value.Replace("'","''") + "'");

			if (user_count == 1)
			{
				string guid = Guid.NewGuid().ToString();
				string sql = @"
declare @user_id int

select @user_id = us_id
	from users
	where us_email = N'$email'

insert into emailed_links
	(el_id, el_date, el_email, el_action, el_user_id)
	values ('$guid', getdate(), N'$email', N'forgot', @user_id)";

				sql = sql.Replace("$guid",guid);
				sql = sql.Replace("$email", email.Value.Replace("'","''"));

				dbutil.execute_nonquery(sql);

				string result = btnet.Email.send_email(
					email.Value,
					Util.get_setting("NotificationEmailFrom",""),
					"", // cc
					"reset password",

					"Click to <a href='"
						+ Util.get_setting("AbsoluteUrlPrefix","")
						+ "change_password.aspx?id="
						+ guid
						+ "'>reset password</a>.",

					System.Web.Mail.MailFormat.Html);

				if (result == "")
				{
					msg.InnerHtml = "An email has been sent to " + email.Value;
					msg.InnerHtml += "<br>Please click on the link in the email message.";
				}
				else
				{
					msg.InnerHtml = "There was a problem sending the email.";
					msg.InnerHtml += "<br>" + result;
				}
			}
			else
			{
				msg.InnerHtml = "Unknown email address.<br>Are you sure you spelled it correctly?";
			}
		}
	}
}

</script>

<html>
<head>
<title id="titl" runat="server">btnet forgot password</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body onload="document.forms[0].email.focus()">
<table border=0><tr>

<%

Response.Write (Application["custom_logo"]);

%>

</table>


<div align="center">
<table border=0><tr><td>
<form class=frm runat="server">
	<table border=0>

	<tr>
	<td class=lbl>Email:</td>
	<td><input runat="server" type=text class=txt id="email" size=40 maxlength=40></td>
	</tr>

	<tr><td colspan=2 align=left>
	<span runat="server" class=err id="msg">&nbsp;</span>
	</td></tr>

	<tr><td colspan=2 align=center>
	<input class=btn type=submit value="Send password link to my email" runat="server">
	</td></tr>

	</table>
</form>

<a href="default.aspx">Return to login page</a>

</td></tr></table>

</div>
</body>
</html>