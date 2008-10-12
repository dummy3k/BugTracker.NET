/*
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
*/

using System;
using System.Web;
using System.Data;
using System.IO;
using System.Text;
using System.Data.SqlClient;
using System.Collections.Generic;
using Lucene.Net;

namespace btnet
{
	public class MyLucene
	{
        public static string index_path = btnet.Util.get_lucene_index_folder();

        public static Lucene.Net.Analysis.Standard.StandardAnalyzer anal = new Lucene.Net.Analysis.Standard.StandardAnalyzer();
        public static Lucene.Net.QueryParsers.QueryParser parser = new Lucene.Net.QueryParsers.QueryParser("text", anal);
        public static Lucene.Net.Highlight.Formatter formatter = new Lucene.Net.Highlight.SimpleHTMLFormatter(
                    "<span style='background:yellow;'>",
                    "</span>");
        
        public static Lucene.Net.Highlight.SimpleFragmenter fragmenter = new Lucene.Net.Highlight.SimpleFragmenter(400);
        
        public static object my_lock = new object(); // for a lock

        ///////////////////////////////////////////////////////////////////////
        static Lucene.Net.Documents.Document create_doc(int bug_id, int post_id, string text)
        {
           // btnet.Util.write_to_log("indexing " + Convert.ToString(bug_id));

            Lucene.Net.Documents.Document doc = new Lucene.Net.Documents.Document();
            
            //Fields f = new Lucene.Net.Documents.Field(
                            
            doc.Add(new Lucene.Net.Documents.Field(
                "bg_id",
                Convert.ToString(bug_id),
                Lucene.Net.Documents.Field.Store.YES,
                Lucene.Net.Documents.Field.Index.UN_TOKENIZED));

            doc.Add(new Lucene.Net.Documents.Field(
                "bp_id",
                Convert.ToString(post_id),
                Lucene.Net.Documents.Field.Store.YES,
                Lucene.Net.Documents.Field.Index.UN_TOKENIZED));

            // For the highlighter, store the raw text
            doc.Add(new Lucene.Net.Documents.Field(
                "raw_text",
                text,
                Lucene.Net.Documents.Field.Store.YES,
                Lucene.Net.Documents.Field.Index.UN_TOKENIZED));

            doc.Add(new Lucene.Net.Documents.Field(
                "text",
                new System.IO.StringReader(text)));

            return doc;
        }

        // create a new index
        static void threadproc_build(object obj)
		{
            lock (my_lock)
            {
                try
                {
                    System.Web.HttpApplicationState app = (System.Web.HttpApplicationState)obj;

                    btnet.Util.write_to_log("started creating Lucene index using folder " + MyLucene.index_path);
                    Lucene.Net.Index.IndexWriter writer = new Lucene.Net.Index.IndexWriter(index_path, anal, true);

                    DbUtil dbutil = new DbUtil();

                    // index the bugs
                    DataSet ds = dbutil.get_dataset(@"
    select bg_id, 
    case 
        when isnull(bg_tags,'') <> '' then bg_short_desc + ' / ' + bg_tags
        else bg_short_desc 
        end [text] 
    from bugs");

                    foreach (DataRow dr in ds.Tables[0].Rows)
                    {
                        writer.AddDocument(MyLucene.create_doc(
                            (int)dr["bg_id"],
                            0,
                            (string)dr["text"]));
                    }

                    // index the bug posts
                    ds = dbutil.get_dataset(@"
    select bp_bug, bp_id, 
    isnull(bp_comment_search,bp_comment) [text] 
    from bug_posts 
    where bp_type <> 'update'
    and bp_hidden_from_external_users = 0");

                    foreach (DataRow dr in ds.Tables[0].Rows)
                    {
                        writer.AddDocument(MyLucene.create_doc(
                            (int)dr["bp_bug"],
                            (int)dr["bp_id"],
                            (string)dr["text"]));
                    }

                    writer.Optimize();
                    writer.Close();
                    btnet.Util.write_to_log("done creating Lucene index");
                }
                catch (Exception e)
                {
                    btnet.Util.write_to_log("exception building Lucene index: " + e.Message);
                }
            }
		}

        // update an existing index
        static void threadproc_update(object obj)
        {
            // just to be safe, make the worker threads wait for each other
            //System.Console.Beep(540, 20);
            lock (my_lock)
            {
                //System.Console.Beep(840, 20);
                try
                {
                    Lucene.Net.Index.IndexModifier modifier = new Lucene.Net.Index.IndexModifier(index_path, anal, false);

                    // same as buid, but uses "modifier" instead of write.
                    // uses additional "where" clause for bugid

                    int bug_id = (int)obj;

                    btnet.Util.write_to_log("started updating Lucene index using folder " + MyLucene.index_path);

                    modifier.DeleteDocuments(new Lucene.Net.Index.Term("bg_id", Convert.ToString(bug_id)));

                    DbUtil dbutil = new DbUtil();

                    // index the bugs
                    DataSet ds = dbutil.get_dataset(@"
    select bg_id, 
    case 
        when isnull(bg_tags,'') <> '' then bg_short_desc + ' / ' + bg_tags
        else bg_short_desc 
        end [text] 
    from bugs where bg_id = " + Convert.ToString(bug_id));

                    foreach (DataRow dr in ds.Tables[0].Rows)
                    {
                        modifier.AddDocument(MyLucene.create_doc(
                            (int)dr["bg_id"],
                            0,
                            (string)dr["text"]));
                    }

                    // index the bug posts
                    ds = dbutil.get_dataset(@"
    select bp_bug, bp_id, 
    isnull(bp_comment_search,bp_comment) [text] 
    from bug_posts 
    where bp_type <> 'update'
    and bp_hidden_from_external_users = 0
    and bp_bug = " + Convert.ToString(bug_id));

                    foreach (DataRow dr in ds.Tables[0].Rows)
                    {
                        modifier.AddDocument(MyLucene.create_doc(
                            (int)dr["bp_bug"],
                            (int)dr["bp_id"],
                            (string)dr["text"]));
                    }

                    modifier.Flush();
                    modifier.Close();
                    btnet.Util.write_to_log("done updating Lucene index");
                }
                catch (Exception e)
                {
                    btnet.Util.write_to_log("exception building Lucene index: " + e.Message);
                }
            }
        }

		public static void build_lucene_index(System.Web.HttpApplicationState app)
		{
			System.Threading.Thread thread = new System.Threading.Thread(threadproc_build);
			thread.Start(app);
		}


        public static void update_lucene_index(int bug_id)
        {
            System.Threading.Thread thread = new System.Threading.Thread(threadproc_update);
            thread.Start(bug_id);
        }

	}

}


