<%@ Page language="C#"%>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

DbUtil dbutil;
Security security;

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

    dbutil = new DbUtil();
    security = new Security();
    security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK);

    Lucene.Net.Search.Query query = MyLucene.parser.Parse(Request["query"]);
    Lucene.Net.Highlight.QueryScorer scorer = new Lucene.Net.Highlight.QueryScorer(query);
    Lucene.Net.Highlight.Highlighter highlighter = new Lucene.Net.Highlight.Highlighter(MyLucene.formatter, scorer);
    highlighter.SetTextFragmenter(MyLucene.fragmenter); // new Lucene.Net.Highlight.SimpleFragmenter(400));

    StringBuilder sb = new StringBuilder();
    string guid = Guid.NewGuid().ToString().Replace("-", "");
    Dictionary<string, int> dict_already_seen_ids = new Dictionary<string, int>();

    sb.Append(@"
create table #$GUID
(
temp_bg_id int,
temp_bp_id int,
temp_score float,
temp_text nvarchar(3000)
)
    ");

    //System.Console.Beep(1500, 20);
    lock (MyLucene.my_lock)
    {
        //System.Console.Beep(1800, 20);
        Lucene.Net.Search.Searcher searcher = new Lucene.Net.Search.IndexSearcher(MyLucene.index_path);
        Lucene.Net.Search.Hits hits = searcher.Search(query);

        // insert the search results into a temp table which we will join with what's in the database

        for (int i = 0; i < hits.Length(); i++)
        {
            if (dict_already_seen_ids.Count < 100)
            {
                Lucene.Net.Documents.Document doc = hits.Doc(i);
                string bg_id = doc.Get("bg_id");
                if (!dict_already_seen_ids.ContainsKey(bg_id))
                {
                    dict_already_seen_ids[bg_id] = 1;
                    sb.Append("insert into #");
                    sb.Append(guid);
                    sb.Append(" values(");
                    sb.Append(bg_id);
                    sb.Append(",");
                    sb.Append(doc.Get("bp_id"));
                    sb.Append(",");
                    sb.Append(Convert.ToString((hits.Score(i))));
                    sb.Append(",N'");

                    string raw_text = Server.HtmlEncode(doc.Get("raw_text"));
                    Lucene.Net.Analysis.TokenStream stream = MyLucene.anal.TokenStream("", new System.IO.StringReader(raw_text));
                    string highlighted_text = highlighter.GetBestFragments(stream, raw_text, 1, "...").Replace("'", "''");
                    if (highlighted_text == "") // someties the highlighter fails to emit text...
                    {
                        highlighted_text = raw_text.Replace("'","''");
                    }
                    if (highlighted_text.Length > 3000)
                    {
						highlighted_text = highlighted_text.Substring(0,3000);
					}
                    sb.Append(highlighted_text);
                    sb.Append("'");
                    sb.Append(")\n");
                }
            }
            else
            {
                break;
            }
        }
        searcher.Close();
    }


    sb.Append(@"
select '#ffffff', bg_id [id], temp_text [search_desc],
'' [search_source], '' [search_text], bg_reported_date [date], isnull(st_name,'') [status], temp_score [$SCORE]
from bugs
inner join #$GUID t on t.temp_bg_id = bg_id and t.temp_bp_id = 0
left outer join statuses on st_id = bg_status
where $ALTER_HERE

union

select '#ffffff', bg_id, bg_short_desc,
bp_type + ',' + convert(varchar,bp_id),
temp_text, bp_date, isnull(st_name,''), temp_score
from bugs inner join #$GUID t on t.temp_bg_id = bg_id
inner join bug_posts on temp_bp_id = bp_id
left outer join statuses on st_id = bg_status
where $ALTER_HERE

order by t.temp_score desc, bg_id desc

drop table #$GUID

");

    string sql = sb.ToString().Replace("$GUID", guid);
    sql =  btnet.Util.alter_sql_per_project_permissions(sql, security);


    DataSet ds = dbutil.get_dataset (sql);
    Session["bugs_unfiltered"] = ds.Tables[0];
    Session["bugs"] = new DataView(ds.Tables[0]);

    Session["just_did_text_search"] = "yes"; // switch for bugs.aspx
    Session["query"] = Request["query"]; // for util.cs, to persist the text in the search <input>
    Response.Redirect("bugs.aspx");
}

</script>
