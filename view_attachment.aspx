<%@ Page language="C#"%>
<!-- #include file = "inc.aspx" -->
<script language="C#" runat="server">

//Copyright 2002-2007 Corey Trager
//Distributed under the terms of the GNU General Public License


int id;
int bug_id;
String sql;
DbUtil dbutil;
Security security;

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK);

	id = Convert.ToInt32(Request["id"]);
	bug_id = Convert.ToInt32(Request["bug_id"]);

	int permission_level = Bug.get_bug_permission_level(bug_id, security);
	if (permission_level == Security.PERMISSION_NONE)
	{
		Response.Write("You are not allowed to view this item");
		Response.End();
	}

	string var = Request["download"];
	bool download;
	if (var == null || var == "1")
	{
		download=true;
	}
	else
	{
		download=false;
	}


	sql = @"select bp_file, isnull(bp_content_type,'') [bp_content_type] from bug_posts where bp_id = $1";
	sql = sql.Replace("$1", Convert.ToString(id));
	DataRow dr = dbutil.get_datarow(sql);

	string filename = (string) dr["bp_file"];
	string content_type = (string) dr["bp_content_type"];

	// create path
	string upload_folder = Util.get_upload_folder();
	StringBuilder path = new StringBuilder(upload_folder);
	path.Append("\\");
	path.Append(Convert.ToString(bug_id));
	path.Append("_");
	path.Append(Convert.ToString(id));
	path.Append("_");
	path.Append(filename);

	if (System.IO.File.Exists(path.ToString()))
	{

		if (content_type == null || content_type == "")
		{

			string ext = System.IO.Path.GetExtension(path.ToString()).ToLower();

			if (ext == ".txt")
			{
				Response.ContentType = "text/plain";
			}
			else if (ext == ".gif")
			{
				Response.ContentType = "image/GIF";
			}
			else if (ext == ".jpeg" || ext == ".jpg")
			{
				Response.ContentType = "image/JPEG";
			}
			else if (ext == ".doc")
			{
				Response.ContentType = "application/x-msword";
			}
			else if (ext == ".xls")
			{
				Response.ContentType = "application/x-msexcel";
			}
			else if (ext == ".zip")
			{
				Response.ContentType = "application/zip";
			}

		}
		else
		{
			Response.ContentType = content_type;
		}


		if (download)
		{
			Response.AddHeader ("content-disposition","attachment; filename=\"" + filename + "\"");
		}
		else
		{
			Response.AddHeader ("content-disposition","inline; filename=\"" + filename + "\"");
		}



		Response.WriteFile(path.ToString());


	}
	else
	{
		Response.Write ("File not found:<br>" + path.ToString());
	}


}


</script>

