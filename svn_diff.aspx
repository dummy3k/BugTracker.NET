<%@ Page language="C#"%>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->
<script language="C#" runat="server">

/*
The following is an explanation of Unified Diff Format from this web page, from Guido van Rossum, the Python guy:
http://www.artima.com/weblogs/viewpost.jsp?thread=164293

The header lines look like this:

indicator ' ' filename '\t' date ' ' time ' ' timezone

where:

		* indicator is '---' for the old file and '+++' for the new
		* date has the form YYYY-MM-DD
		* time has the form hh:mm:ss.nnnnnnnnn on a 24-hour clock
		* timezone is has the form ('+'|'-') hhmm where hhmm is hours and minutes east
		(if the sign is +) or west (if the sign is -) of GMT/UTC

Each chunk starts with a line that looks like this:

'@@ -' range ' +' range ' @@'

where range is either one unsigned decimal number or two separated by a comma.
The first number is the start line of the chunk in the old or new file.
The second number is chunk size in that file;
it and the comma are omitted if the chunk size is 1.
If the chunk size is 0, the first number is one lower than one would expect
(it is the line number after which the chunk should be inserted or deleted;
in all other cases it gives the first line number or the replaced range of lines).

A chunk then continues with lines starting with
' ' (common line),
'-' (only in old file), or
'+' (only in new file).

If the last line of a file doesn't end in a newline character,
it is displayed with a newline character, and the following line in the chunk has
the literal text (starting in the first column):

'\ No newline at end of file'

*/



Security security;

string left = "";
string right = "";
string diff = "";

string repository_url = "";
string svn_username = "";
string svn_password = "";
string websvn_url = "";

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	
	security = new Security();
	security.check_security( HttpContext.Current, Security.ANY_USER_OK);


	// get info about revision

	if (Request["id"] != null && Request["id"] != "")
	{

		string sql = @"
		select svnrev_revision, svnap_path, svnrev_bug
		from svn_revisions
		inner join svn_affected_paths on svnap_svnrev_id = svnrev_id
		where svnap_id = $id
		order by svnrev_revision desc, svnap_path";

		int svnap_id = Convert.ToInt32(Util.sanitize_integer(Request["id"]));
		sql = sql.Replace("$id", Convert.ToString(svnap_id));

		DataRow dr = btnet.DbUtil.get_datarow(sql);

		// check if user has permission for this bug
		int permission_level = Bug.get_bug_permission_level((int) dr["svnrev_bug"], security);
		if (permission_level == Security.PERMISSION_NONE) {
			Response.Write("You are not allowed to view this item");
			Response.End();
		}

		btnet.Util.get_subversion_connection_info(
			(int) dr["svnrev_bug"],
			ref repository_url,
			ref svn_username,
			ref svn_password,
			ref websvn_url);

		visual_diff(
			(string) dr["svnap_path"],
			(int) dr["svnrev_revision"],
			0);
	}
	else
	{

		btnet.Util.get_subversion_connection_info(
			Convert.ToInt32(Request["hidden_bugid"]),
			ref repository_url,
			ref svn_username,
			ref svn_password,
			ref websvn_url);

		visual_diff(
			Request["path"],
			Convert.ToInt32(Request["rev_1"]),
			Convert.ToInt32(Request["rev_0"]));
	}
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
string svn_diff(string file_path, int revision, int old_revision)
{
	StringBuilder args = new StringBuilder();

	if (old_revision != 0)
	{
		args.Append("diff -r ");

        args.Append(Convert.ToString(old_revision));
        args.Append(":");
        args.Append(Convert.ToString(revision));
        args.Append(" ");
        args.Append(repository_url);
        args.Append(file_path.Replace(" ", "%20"));
	}
	else
	{
		args.Append("diff -c ");
		args.Append(Convert.ToString(revision));
		args.Append(" ");
		args.Append(repository_url);
		args.Append(file_path.Replace(" ","%20"));
	}

	return run_svn(args.ToString());
}


///////////////////////////////////////////////////////////////////////
string svn_cat(string file_path, int revision)
{
	StringBuilder args = new StringBuilder();

	args.Append("cat ");

	args.Append(repository_url);
	args.Append(file_path.Replace(" ","%20"));
	args.Append(" -r ");
	args.Append(Convert.ToString(revision));

	return run_svn(args.ToString());
}

///////////////////////////////////////////////////////////////////////
void visual_diff(string file_path, int revision, int old_revision)
{
	Regex regex = new Regex("\n");
	string line = "";


	// do the diff

	if (old_revision != 0)
	{
		if (old_revision > revision)
		{
			int swap = revision;
			revision = old_revision;
			old_revision = swap;
		}
	}

	string diff_text = svn_diff(file_path, revision, old_revision);

	Util.write_to_log("diff_text:\n" + diff_text);

    if (diff_text == "")
    {
        Response.Write("No differences.");
        Response.End();
    }


	// first, split everything into lines
	string[] diff_lines = regex.Split(diff_text.Replace("\r\n","\n"));

    string old_file_path = file_path;

    if (old_revision == 0)
	{
		// get the old revision number
		line = diff_lines[2];
		int old_rev_pos1 = line.ToLower().IndexOf("(revision ");  // 10 chars long
		int old_rev_pos_start_of_int = old_rev_pos1 + 10;
		int old_rev_after_int = line.IndexOf(")",old_rev_pos_start_of_int);
		string old_revision_string = line.Substring(old_rev_pos_start_of_int,
			old_rev_after_int - old_rev_pos_start_of_int);

		old_revision = Convert.ToInt32(old_revision_string);



	}


	// get the source code for both the left and right
	string left_text = HttpUtility.HtmlEncode(svn_cat(old_file_path, old_revision));
	string right_text = HttpUtility.HtmlEncode(svn_cat(file_path, revision));

    // first, split everything into lines
	string[] left_lines = regex.Split(left_text.Replace("\r\n","\n"));
	string[] right_lines = regex.Split(right_text.Replace("\r\n","\n"));


	// for formatting line numbers
	int max_lines = left_lines.Length;
	if (right_lines.Length > left_lines.Length) max_lines = right_lines.Length;

	// I just want to pad left a certain number of places
	// probably any 5th grader would know how to do this better than me
    string blank = "";
	int digit_places = 1;
	if (max_lines > 9)	digit_places++;
	if (max_lines > 99) digit_places++;
	if (max_lines > 999) digit_places++;
	if (max_lines > 9999) digit_places++;
	if (max_lines > 99999) digit_places++;
	if (max_lines > 999999) digit_places++;


	int lx = 0;
	int rx = 0;
	int dx = 4;

	StringBuilder sL = new StringBuilder();
	StringBuilder sR = new StringBuilder();

	bool minus_followed_by_plus = false;

	// L E F T
	// L E F T
	// L E F T

	sL.Append("<div class=difffile>" + diff_lines[2].Substring(4) + "</div>");
	sR.Append("<div class=difffile>" + diff_lines[3].Substring(4) + "</div>");

    while (dx < diff_lines.Length)
	{
		line = diff_lines[dx];
		if (line.StartsWith("@@ -") && line.EndsWith(" @@"))
		{



			// See comment at the top of this file explaining Unified Diff Format
			// Parse out the left start line.  For example, the "38" here:
			// @@ -38,18 +39,12 @@
			// Note that the range could also be specified as follows, with the number of lines assumed to be 1
			// @@ -1 +1,2 @@


            int pos1 = line.IndexOf("-");
            int pos2 = Math.Min(line.IndexOf(" ", pos1), line.IndexOf(",", pos1));
            //string left_start_line_string = line.Substring(pos1 + 1, (pos2-1) - pos1);
            string left_start_line_string = line.Substring(pos1 + 1, pos2 - (pos1 + 1));
            int start_line = Convert.ToInt32(left_start_line_string);
            start_line -= 1; // adjust for zero based index

            // parse out the number of lines, the "18" in our example. If just one line, it might not be specified.
//            int pos3 = line.IndexOf(" +");
//            int left_num_of_lines;
//            if ((pos3) - (pos2 + 1) >= 0)
//            {
//            string left_num_of_lines_string = line.Substring(pos2 + 1, (pos3) - (pos2 + 1));
//                left_num_of_lines = Convert.ToInt32(left_num_of_lines_string);
//            }
//            else
//            {
//                left_num_of_lines = 1; // this goes along with the second number optional case
//            }

            // advance through left file until we hit the starting line of the range
            while (lx < start_line)
            {
                sL.Append("<span class=diffnum>");
                sL.Append(Convert.ToString(lx+1).PadLeft(digit_places,'0'));
                sL.Append(" </span>");
                sL.Append(left_lines[lx++]);
                sL.Append("\n");
            }


			// we are positioned in the left file at the start of the diff blockk
            dx++;
            line = diff_lines[dx];
			minus_followed_by_plus = false;
            while (dx < diff_lines.Length
            && !(line.StartsWith("@@ -") && line.EndsWith(" @@")))
            {
                if (line.StartsWith("+"))
                {
	                if (!minus_followed_by_plus)
	                {
		                sL.Append("<span class=diffnum>");
	                    sL.Append(blank.PadLeft(digit_places,' '));
	                    sL.Append(" </span>");
	                    sL.Append("<span class=diffblank>&nbsp;&nbsp;&nbsp;&nbsp;</span>\n");
					}
                    minus_followed_by_plus = false;
                }
                else if (line.StartsWith("-"))
                {

	                sL.Append("<span class=diffnum>");
                    sL.Append(Convert.ToString(lx+1).PadLeft(digit_places,'0'));
                    sL.Append(" </span>");

	                minus_followed_by_plus = false;
	                if (dx < diff_lines.Length-2)
	                {
						// a minus/plus combo is a change
						if (diff_lines[dx+1].StartsWith("+"))
						{
			                minus_followed_by_plus = true;
						}
					}

	                if (minus_followed_by_plus)
	                {
	                    sL.Append("<span class=diffchg>");
					}
					else
					{
	                    sL.Append("<span class=diffdel>");
					}
                    sL.Append(left_lines[lx++]);
                    sL.Append("</span>\n");
                }
                else if (line.StartsWith("\\") || line == "")
                {
					minus_followed_by_plus = false;
					//break;
				}
                else
                {
	                sL.Append("<span class=diffnum>");
                    sL.Append(Convert.ToString(lx+1).PadLeft(digit_places,'0'));
                    sL.Append(" </span>");
                    sL.Append(left_lines[lx++]);
                    sL.Append("\n");
                    minus_followed_by_plus = false;
                }

                dx++;

                if (dx < diff_lines.Length)
                {
                    line = diff_lines[dx];
                }
            } // end of range block
		}

        if (dx < diff_lines.Length && line.StartsWith("@@ -") && line.EndsWith(" @@"))
        {
			continue;
		}
		else
		{
			break;
		}

	} // end of all blocks

	// advance through left file until we hit the starting line of the range

	while (lx < left_lines.Length)
	{
        sL.Append("<span class=diffnum>");
        sL.Append(Convert.ToString(lx+1).PadLeft(digit_places,'0'));
        sL.Append(" </span>");
		sL.Append(left_lines[lx++]);
		sL.Append("\n");
	}



    // R I G H T
    // R I G H T
    // R I G H T
    dx = 4;
    while (dx < diff_lines.Length)
    {
        line = diff_lines[dx];
        if (line.StartsWith("@@ -") && line.EndsWith(" @@"))
        {

			// See comment at the top of this file explaining Unified Diff Format

            // parse out the right start line.  For example, the "39" here: @@ -38,18 +39,12 @@
            int pos1 = line.IndexOf("+");

            int pos2 = line.IndexOf(",", pos1);
            if (pos2 == -1) pos2 = line.IndexOf(" ", pos1);

            //string right_start_line_string = line.Substring(pos1 + 1, (pos2 - 1) - pos1);
            string right_start_line_string = line.Substring(pos1 + 1, pos2 - (pos1 + 1));
            int start_line = Convert.ToInt32(right_start_line_string);
            start_line -= 1; // adjust for zero based index

            // parse out the number of lines, the "12" in our example
//            int pos3 = line.IndexOf(" ",pos1);
//            int right_num_of_lines;
//            if ((pos3) - (pos2 + 1) > 0)
//            {
//            string right_num_of_lines_string = line.Substring(pos2 + 1, (pos3) - (pos2 + 1));
//                right_num_of_lines = Convert.ToInt32(right_num_of_lines_string);
//            }
//            else
//            {
//                right_num_of_lines = 1; // this goes along with the second number optional case
//            }

            // advance through right file until we hit the starting line of the range
            while (rx < start_line)
            {
                sR.Append("<span class=diffnum>");
                sR.Append(Convert.ToString(rx+1).PadLeft(digit_places,'0'));
                sR.Append(" </span>");
                sR.Append(right_lines[rx++]);
                sR.Append("\n");
            }


			// we are positioned in the right file at the start of the diff block
            dx++;
            line = diff_lines[dx];
			minus_followed_by_plus = false;
            while (dx < diff_lines.Length && !(line.StartsWith("@@ -") && line.EndsWith(" @@")))
            {
                if (line.StartsWith("-"))
                {
	                minus_followed_by_plus = false;
	                if (dx < diff_lines.Length-2)
	                {
						// a minus/plus combo is a change
						if (diff_lines[dx+1].StartsWith("+"))
						{
			                minus_followed_by_plus = true;
						}
					}

					// if THIS is left side of a change
					if (!minus_followed_by_plus)
					{
						sR.Append("<span class=diffnum>");
						sR.Append(blank.PadLeft(digit_places,' '));
						sR.Append(" </span>");
                    	sR.Append("<span class=diffblank>&nbsp;&nbsp;&nbsp;&nbsp;</span>\n");
					}


                }
                else if (line.StartsWith("+"))
                {
					sR.Append("<span class=diffnum>");
					sR.Append(Convert.ToString(rx+1).PadLeft(digit_places,'0'));
					sR.Append(" </span>");
					if (minus_followed_by_plus)
					{
						sR.Append("<span class=diffchg>");
					}
					else
					{
						sR.Append("<span class=diffadd>");
					}
					sR.Append(right_lines[rx++]);
					sR.Append("</span>\n");
					minus_followed_by_plus = false;
                }
                else if (line.StartsWith("\\") || line == "")
                {
					minus_followed_by_plus = false;
					//break;
				}
                else
                {
	                sR.Append("<span class=diffnum>");
                    sR.Append(Convert.ToString(rx+1).PadLeft(digit_places,'0'));
                    sR.Append(" </span>");
                    sR.Append(right_lines[rx++]);
                    sR.Append("\n");
					minus_followed_by_plus = false;
                }

                dx++;

                if (dx < diff_lines.Length)
                {
                    line = diff_lines[dx];
                }

            } // end of range block
		}

        if (dx < diff_lines.Length && line.StartsWith("@@ -") && line.EndsWith(" @@"))
        {
			continue;
		}
		else
		{
			break;
		}

	} // end of all blocks

	// advance through right file until we're done

	while (rx < right_lines.Length)
	{
        sR.Append("<span class=diffnum>");
		sR.Append(Convert.ToString(rx+1).PadLeft(digit_places,'0'));
		sR.Append(" </span>");
		sR.Append(right_lines[rx++]);
		sR.Append("\n");
	}

	left = sL.ToString();
	right = sR.ToString();
	diff = diff_text;



}


</script>

<html>
<title>svn diff</title>
<style>
.diffadd {background: #aaffaa;}
.diffdel {background: #ffaaaa;}
.diffchg {background: yellow;}
.diffblank {background: #cccccc;}
.diffnum {color: gray;}
.difffile {background: #000099; color: white; font-size: 12px; letter-spacing: 2px; font-weight: bold; border: 1px solid black; padding: 4px; margin-bottom: 4px;}
</style>

<body>

<p>

<span class=diffadd style="border: 1px solid black;">&nbsp;&nbsp;&nbsp;&nbsp;</span> = added,&nbsp;
<span class=diffdel style="border: 1px solid black;">&nbsp;&nbsp;&nbsp;&nbsp;</span> = deleted,&nbsp;
<span class=diffchg style="border: 1px solid black;">&nbsp;&nbsp;&nbsp;&nbsp;</span> = changed,&nbsp;

<table border=0 width=100%><tr>

<td valign=top width=50%>
<div style="overflow-x: auto; border: 1px solid gray;  padding: 4px;  margin: 3px">
<pre>
<% Response.Write(left); %>
</pre>
</div>

<td>&nbsp;&nbsp;

<td valign=top width=50%>
<div style="overflow-x: auto; border: 1px solid gray; padding: 4px; margin: 3px;">
<pre>
<% Response.Write(right); %>
</pre>
</div>

</table>

<p>
<script>
function show_raw_diff()
{
	el = document.getElementById("raw_diff");
	el.style.display = "block"
}
</script>

<a href="javascript: show_raw_diff()">show raw diff format</a>
<pre id="raw_diff" style="display:none;">
<% Response.Write(diff); %>
</pre>

</body>
</html>
