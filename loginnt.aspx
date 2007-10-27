<%@ Page language="C#"%>
<!--
Copyright 2002-2007 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->
<!-- #include file = "inc_logon.inc" -->

<script language="C#" runat="server">


DbUtil dbutil;
string sql;

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{
	dbutil = new DbUtil();
	dbutil.get_sqlconnection();

	Util.do_not_cache(Response);

	// Get authentication mode
	string auth_mode = Util.get_setting("WindowsAuthentication","0");

	// If manual authentication only, we shouldn't be here, so redirect to manual screen
	if (auth_mode == "0") {
		redirect("default.aspx");
	}

	// Get the logon user from IIS
	string domain_windows_username = Request.ServerVariables["LOGON_USER"];

	if (domain_windows_username == "") {
		// If the logon user is blank, then the page is misconfigured
		// in IIS. Do nothing and let the HTML display.
	} else {

		// Extract the user name from the logon ID
		int pos = domain_windows_username.IndexOf("\\") + 1;
		string windows_username =
			domain_windows_username.Substring(pos, domain_windows_username.Length-pos);

		// Fetch the user's information from the users table
		sql = @"select us_id, us_username
			from users
			where us_username = '$us'
			and us_active = 1";
		sql = sql.Replace("$us", windows_username.Replace("'","''"));

		DataRow dr = dbutil.get_datarow(sql);
		if (dr != null) {
			// The user was found, so bake a cookie and redirect
			int userid = (int) dr["us_id"];
			create_session (
				userid,
				(string) dr["us_username"],
				"1");
			redirect();
		}

		// Try fetching the guest user.
		sql = @"select us_id, us_username
			from users
			where us_username = 'guest'
			and us_active = 1";

		dr = dbutil.get_datarow(sql);
		if (dr != null) {
			// The Guest user was found, so bake a cookie and redirect
			int userid = (int) dr["us_id"];
			create_session (
				userid,
				(string) dr["us_username"],
				"1");
			redirect();
		}

		// If using mixed-mode authentication and we got this far,
		// then we can't sign in using integrated security. Redirect
		// to the manual screen.
		if (auth_mode != "1") {
			redirect("default.aspx?msg=user+not+valid");
		}

		// If we are still here, then toss a 401 error.
		Response.StatusCode = 401;
		Response.End();
	}
}



</script>

<html>
<head>
<title>btnet logon</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body>
<h1>Configuration Problem</h1>

<p>This page has not been properly configured for Windows Integrated
Authentication. Please contact your web administrator.</p>

<p>Windows Integrated Authentication requires that this page (loginNT.aspx)
does not permit anonymous access and Windows Integrated Security is selected
as the authentication protocol.</p>

<p><a href="default.aspx?msg=configuration+problem">Go to logon page.</a></p>

</body>
</html>