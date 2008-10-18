<%@ Page language="C#"%>
<!-- #include file = "inc.aspx" -->

<script runat="server">

DbUtil dbutil;
Security security;

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK);

	string bugid = Util.sanitize_integer(Request["bugid"]);

	// check permission
	int permission_level = Bug.get_bug_permission_level(Convert.ToInt32(bugid), security);
	if (permission_level != Security.PERMISSION_NONE)
	{

		Response.Write(@"

<style>
.cmt_text
{
font-family: courier new;
font-size: 8pt;
}
.pst
{
font-size: 7pt;
}
</style>");
		

		PrintBug.write_posts(
			Response,
			Convert.ToInt32(bugid),
			permission_level,
			false,
			false,
			false,
			security.user);		
	
	}
	else
	{
		Response.Write ("");
	}
}


</script>

