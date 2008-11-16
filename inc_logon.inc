<script language="C#" runat="server">

	///////////////////////////////////////////////////////////////////////
	void create_session(int userid, string username, string NTLM)
	{

		// Generate a random session id
		// Don't use a regularly incrementing identity
		// column because that can be guessed.
		string guid = Guid.NewGuid().ToString();

		btnet.Util.write_to_log("guid=" + guid);

		string sql = @"insert into sessions (se_id, se_user) values('$gu', $us)";
		sql = sql.Replace("$gu", guid);
		sql = sql.Replace("$us", Convert.ToString(userid));

		dbutil.execute_nonquery(sql);

		string sAppPath = Request.Url.AbsolutePath;
		sAppPath = sAppPath.Substring(0, sAppPath.LastIndexOf('/'));
		Util.write_to_log("AppPath:" + sAppPath);

		Response.Cookies["se_id"].Value = guid;
		Response.Cookies["se_id"].Path = sAppPath;
		Response.Cookies["user"]["name"] = username;
		Response.Cookies["user"]["NTLM"] = NTLM;
		Response.Cookies["user"].Path = sAppPath;
		DateTime dt = DateTime.Now;
		TimeSpan ts = new TimeSpan(365, 0, 0, 0);
		Response.Cookies["user"].Expires = dt.Add(ts);
	}

	///////////////////////////////////////////////////////////////////////
	void redirect()
	{

		// redirect to the page the user was going to or start off with bugs.aspx
		string url = Request.QueryString["url"];
		string qs = Request.QueryString["qs"];

		if (url == null)
		{
			Response.Redirect("bugs.aspx");
		}
		else if (url.Trim() == "")
		{
			Response.Redirect("bugs.aspx");
		}
		else if (url == Request.ServerVariables["URL"])
		{
			Response.Redirect("bugs.aspx");
		}
		else
		{
			Response.Redirect(url + "?" + HttpUtility.UrlDecode(qs));
		}
	}

	///////////////////////////////////////////////////////////////////////
	void redirect(string url)
	{
		//redirect to the url supplied with the original querystring
		if (url.IndexOf("?") > 0)
		{
			Response.Redirect(url + "&url=" + Request.QueryString["url"] + "&qs=" + Request.QueryString["qs"]);
		}
		else
		{
			Response.Redirect(url + "?url=" + Request.QueryString["url"] + "&qs=" + Request.QueryString["qs"]);
		}
	}

</script>