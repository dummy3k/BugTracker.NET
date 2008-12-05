<script language="C#" runat="server">

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