<%@ Page Language="C#" %>

<!--
Copyright 2002-2008 Corey Trager
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

	if (auth_mode == "0")
	{
		redirect("default.aspx");
	}

	// Get the logon user from IIS
	string domain_windows_username = Request.ServerVariables["LOGON_USER"];

	if (domain_windows_username == "")
	{
		// If the logon user is blank, then the page is misconfigured
		// in IIS. Do nothing and let the HTML display.
	}
	else
	{

		// Extract the user name from the logon ID
		int pos = domain_windows_username.IndexOf("\\") + 1;
		string windows_username =
			domain_windows_username.Substring(pos, domain_windows_username.Length-pos);


		// Fetch the user's information from the users table
		sql = @"select us_id, us_username
			from users
			where us_username = N'$us'
			and us_active = 1";
		sql = sql.Replace("$us", windows_username.Replace("'","''"));

		DataRow dr = dbutil.get_datarow(sql);
		if (dr != null)
		{
			// The user was found, so bake a cookie and redirect
			int userid = (int) dr["us_id"];
			create_session (
				userid,
				(string) dr["us_username"],
				"1");
			redirect();
		}

        // Is self register enabled for users authenticated by windows?
        // If yes, then automatically insert a row in the user table
        bool enable_auto_registration = (Util.get_setting("EnableWindowsUserAutoRegistration","1") == "1");
        if (enable_auto_registration)
        {
            string template_user = Util.get_setting("WindowsUserAutoRegistrationUserTemplate", "guest");

            string firstName = windows_username;
            string lastName = windows_username;
            string displayName = windows_username;
            string email = string.Empty;

            // From the browser, we only know the Windows username.  Maybe we can get the other
            // info from LDAP?
            if (Util.get_setting("EnableWindowsUserAutoRegistrationLdapLookup", "0") == "1")
            {
                using (System.DirectoryServices.DirectoryEntry myLdapConnection = new System.DirectoryServices.DirectoryEntry())
                {
                    myLdapConnection.Path = Util.get_setting("WindowsUserAutoRegistrationLdapLookupSearchPath", null);
                    myLdapConnection.AuthenticationType = (System.DirectoryServices.AuthenticationTypes)System.Enum.Parse(typeof(System.DirectoryServices.AuthenticationTypes), Util.get_setting("LdapAuthType", "Basic"));
                    myLdapConnection.Username = Util.get_setting("WindowsUserAutoRegistrationLdapLookupUser", string.Empty);
                    myLdapConnection.Password = Util.get_setting("WindowsUserAutoRegistrationLdapLookupPassword", string.Empty);

                    using (System.DirectoryServices.DirectorySearcher search = new System.DirectoryServices.DirectorySearcher(myLdapConnection))
                    {
                        string searchFilter = Util.get_setting("WindowsUserAutoRegistrationLdapLookupUserFiler", "(sAMAccountName=%windows_username%)");
                        search.Filter = searchFilter.Replace("%windows_username%", windows_username);

                        System.DirectoryServices.SearchResult result = search.FindOne();
                        if (result != null)
                        {
                            firstName = get_ldap_property_value(result, "givenname", firstName);
                            lastName = get_ldap_property_value(result, "sn", lastName);
                            displayName = get_ldap_property_value(result, "displayName", displayName); ;
                            email = get_ldap_property_value(result, "mail", email); ;
                        }
                    }

                }
            }


            // create the user
            sql = @"
IF NOT EXISTS (SELECT us_id FROM users WHERE us_username = '$username')
BEGIN

	insert into users
	(
		us_username,
		us_salt,
		us_password,
		us_firstname,
		us_lastname,
		us_email,
		us_admin,
		us_default_query,
		us_enable_notifications,
		us_auto_subscribe,
		us_auto_subscribe_own_bugs,
		us_auto_subscribe_reported_bugs,
		us_send_notifications_to_self,
		us_active,
		us_bugs_per_page,
		us_forced_project,
		us_reported_notifications,
		us_assigned_notifications,
		us_subscribed_notifications,
		us_signature,
		us_use_fckeditor,
		us_enable_bug_list_popups,
		us_created_user,
		us_org,
		us_most_recent_login_datetime
	)
	select
		N'$username',
		0,
		'$password',
		N'$firstname',
		N'$lastname',
		N'$email',
		us_admin,
		us_default_query,
		us_enable_notifications,
		us_auto_subscribe,
		us_auto_subscribe_own_bugs,
		us_auto_subscribe_reported_bugs,
		us_send_notifications_to_self,
		1,
		us_bugs_per_page,
		us_forced_project,
		us_reported_notifications,
		us_assigned_notifications,
		us_subscribed_notifications,
		N'$signature',
		us_use_fckeditor,
		us_enable_bug_list_popups,
		us_created_user,
		us_org,
		GETDATE()
		from users
		where us_username = '$template_user'

		declare @usid int


	select @usid = scope_identity()

	insert into project_user_xref
		(pu_project,
		pu_user,
		pu_auto_subscribe,
		pu_permission_level,
		pu_admin)

	select
		pu_project,
		@usid,
		pu_auto_subscribe,
		pu_permission_level,
		pu_admin
		from project_user_xref
		inner join users on us_id = pu_user
		where us_username = '$template_user'

	select
		@usid us_id,
		N'$username' us_username

END";

            sql = sql.Replace("$username", windows_username.Replace("'", "''"));
            sql = sql.Replace("$firstname", firstName.Replace("'", "''"));
            sql = sql.Replace("$lastname", lastName.Replace("'", "''"));
            sql = sql.Replace("$email", email.Replace("'", "''"));
            sql = sql.Replace("$signature", displayName.Replace("'", "''"));
            sql = sql.Replace("$template_user", template_user.Replace("'", "''"));

            // Password doesn't matter, but don't let it be something that others can guess
            string guid = Guid.NewGuid().ToString();
            sql = sql.Replace("$password", guid);

            dr = dbutil.get_datarow(sql);
            if (dr != null) // automatically created the user
            {
                // The user was created, so bake a cookie and redirect
                create_session(
                    (int)dr["us_id"],
                    windows_username.Replace("'", "''"),
                    "1");
                redirect();
            }
        }


		// Try fetching the guest user.
		sql = @"select us_id, us_username
			from users
			where us_username = 'guest'
			and us_active = 1";

		dr = dbutil.get_datarow(sql);
		if (dr != null)
		{
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
		if (auth_mode != "1")
		{
			redirect("default.aspx?msg=user+not+valid");
		}

		// If we are still here, then toss a 401 error.
		Response.StatusCode = 401;
		Response.End();
	}
}

///////////////////////////////////////////////////////////////////////
string get_ldap_property_value(System.DirectoryServices.SearchResult result, string propertyName, string defaultValue)
{
	System.DirectoryServices.ResultPropertyValueCollection values = result.Properties[propertyName];
	if (values != null && values.Count == 1 && values[0] is string)
	{
		return (string)values[0];
	}
	else
	{
		return defaultValue;
	}
}



</script>

<html>
<head>
<title>btnet logon</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body>
    <h1>
        Configuration Problem</h1>
    <p>
        This page has not been properly configured for Windows Integrated Authentication.
        Please contact your web administrator.</p>
    <p>
        Windows Integrated Authentication requires that this page (loginNT.aspx) does not
        permit anonymous access and Windows Integrated Security is selected as the authentication
        protocol.</p>
    <p>
        <a href="default.aspx?msg=configuration+problem">Go to logon page.</a></p>
</body>
</html>


