<%@ Page language="C#"%>
<!--
Copyright 2002-2007 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">


///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	HttpCookie cookie = Request.Cookies["history_inline"];

	if (cookie == null || Request.Cookies["history_inline"].Value == "0")
	{
		Response.Cookies["history_inline"].Value = "1";
	}
	else
	{
		Response.Cookies["history_inline"].Value = "0";
	}
	Response.Cookies["history_inline"].Expires = System.DateTime.Now.AddYears(30);
	Response.Redirect ("edit_bug.aspx?id=" + Request.QueryString["id"], false);
}



</script>