<%@ Page language="C#"%>
<%@ Import Namespace="System.Data.SqlClient" %>
<!-- #include file = "inc.aspx" -->
<script language="C#" runat="server">

//Copyright 2002-2008 Corey Trager
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

    // First, try to find it in the bug_post_attachments table.
    sql = @"select bpa_content 
            from bug_post_attachments
            where bpa_post = @bp";

    bool foundInDatabase = false;
    String foundAtPath = null;
    using (SqlCommand cmd = new SqlCommand(sql))
    {
        cmd.Parameters.AddWithValue("@bp", id);

        // Use an SqlDataReader so that we can write out the blob data in chunks.
        
        using (SqlDataReader reader = dbutil.execute_reader(cmd, CommandBehavior.CloseConnection | CommandBehavior.SequentialAccess))
        {
            if (reader.Read()) // Did we find the content in the database?
            {
                foundInDatabase = true;
            }
            else
            {
                // Otherwise, try to find the content in the UploadFolder.

	string upload_folder = Util.get_upload_folder();
                if (upload_folder != null)
                {
	StringBuilder path = new StringBuilder(upload_folder);
	path.Append("\\");
	path.Append(Convert.ToString(bug_id));
	path.Append("_");
	path.Append(Convert.ToString(id));
	path.Append("_");
	path.Append(filename);

	if (System.IO.File.Exists(path.ToString()))
	{
                        foundAtPath = path.ToString();
                    }
                }
            }

            // We must have found the content in the database or on the disk to proceed.

            if (!foundInDatabase && foundAtPath == null)
            {
                Response.Write("File not found:<br>" + filename);
                return;
            }

            // Write the ContentType header.

		if (content_type == null || content_type == "")
		{

                string ext = System.IO.Path.GetExtension(filename).ToLower();

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

            // Write the data.

            if (foundInDatabase)
            {
                long totalRead = 0;
                long dataLength = reader.GetBytes(0, 0, null, 0, 0);
                byte[] buffer = new byte[16 * 1024];

                while (totalRead < dataLength)
                {
                    long bytesRead = reader.GetBytes(0, totalRead, buffer, 0, (int)Math.Min(dataLength - totalRead, buffer.Length));
                    totalRead += bytesRead;

                    Response.OutputStream.Write(buffer, 0, (int)bytesRead);
                }
            }
            else if (foundAtPath != null)
            {
                Response.WriteFile(foundAtPath);
	}
	else
	{
                Response.Write("File not found:<br>" + filename);
            }
        }
	}


}


</script>

