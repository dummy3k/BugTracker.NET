<%@ Page language="C#"%>
<!-- #include file = "inc.aspx" -->
<script language="C#" runat="server">


// *****>>>>>> Intentionally not putting copyright in HTML comment, because of text/plain content type.
//Copyright 2002-2009 Corey Trager
//Distributed under the terms of the GNU General Public License


Security security;

string repository_url = "";
string svn_username = "";
string svn_password = "";
string websvn_url = "";


///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{
	Util.do_not_cache(Response);
	Response.ContentType = "text/plain";
	
	security = new Security();
	security.check_security( HttpContext.Current, Security.ANY_USER_OK);

	btnet.Util.get_subversion_connection_info(
		Convert.ToInt32(Request["bugid"]),
		ref repository_url,
		ref svn_username,
		ref svn_password,
		ref websvn_url);

	string text = svn_cat(Request["path"], Convert.ToInt32(Request["rev"]));
	Response.Write (text);

}

///////////////////////////////////////////////////////////////////////
string run_svn(string args)
{

	string output = Util.run_svn(args, svn_username, svn_password);
	if (output.StartsWith("ERROR:"))
	{
        Response.Write(output);
		Response.End();
	}
	return output;
}


///////////////////////////////////////////////////////////////////////
string svn_cat(string file_path, int rev)
{
	StringBuilder args = new StringBuilder();

	args.Append("cat ");
	args.Append(repository_url);
	args.Append(file_path.Replace(" ", "%20"));
	args.Append("@");
	args.Append(Convert.ToInt32(rev));

	return run_svn(args.ToString());
}

</script>

