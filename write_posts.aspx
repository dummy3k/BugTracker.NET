<%@ Page language="C#"%>
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

DbUtil dbutil;
Security security;

void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK);

	int bugid = Convert.ToInt32(Request["id"]);
	bool images_inline = (Request["images_inline"] == "1");
	bool history_inline = (Request["history_inline"] == "1");

	int permission_level = Bug.get_bug_permission_level(bugid, security);
	if (permission_level == Security.PERMISSION_NONE)
	{
		Response.Write("You are not allowed to view this item");
		Response.End();
	}

	PrintBug.write_posts(
		Response,
		bugid,
		permission_level,
		true,
		images_inline,
		history_inline,
		security.user);

}

</script>

