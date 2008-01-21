/*
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
*/

using System;
using System.Data;
using System.Data.SqlClient;
using System.Text;

namespace btnet
{

    ///////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////
    // DbUtil
    ///////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////
    public class DbUtil
    {

        //public SqlConnection sqlconn;
        public string connection_string;

        ///////////////////////////////////////////////////////////////////////
        public DataSet command_to_dataset(SqlCommand cmd)
        {

            DataSet ds = new DataSet();
            SqlDataAdapter da = new SqlDataAdapter(cmd);
            da.Fill(ds);
            return ds;

        }

        ///////////////////////////////////////////////////////////////////////
        public object execute_scalar(string sql)
        {
            if (Util.get_setting("LogSqlEnabled", "1") == "1")
            {
                Util.write_to_log("sql=\n" + sql);
            }

            using (SqlConnection conn = get_sqlconnection())
            {
                object returnValue;
                conn.Open();
                SqlCommand cmd = new SqlCommand(sql, conn);
                returnValue = cmd.ExecuteScalar();
                conn.Close();
                return returnValue;
            }
        }

        ///////////////////////////////////////////////////////////////////////
        public object execute_scalar(SqlCommand cmd)
        {
            log_command(cmd);

            using (SqlConnection conn = get_sqlconnection())
            {
                try
                {
                    cmd.Connection = conn;
                    object returnValue;
                    conn.Open();
                    returnValue = cmd.ExecuteScalar();
                    conn.Close();
                    return returnValue;
                }
                finally
                {
                    cmd.Connection = null;
                }
            }
        }

        ///////////////////////////////////////////////////////////////////////
        public void execute_nonquery(string sql)
        {

            if (Util.get_setting("LogSqlEnabled", "1") == "1")
            {
                Util.write_to_log("sql=\n" + sql);
            }

            using (SqlConnection conn = get_sqlconnection())
            {
                conn.Open();
                SqlCommand cmd = new SqlCommand(sql, conn);
                cmd.ExecuteNonQuery();
                conn.Close();
            }
        }

        ///////////////////////////////////////////////////////////////////////
        public void execute_nonquery(SqlCommand cmd)
        {
            log_command(cmd);

            using (SqlConnection conn = get_sqlconnection())
            {
                try
                {
                    cmd.Connection = conn;
                    conn.Open();
                    cmd.ExecuteNonQuery();
                    conn.Close();
                }
                finally
                {
                    cmd.Connection = null;
                }
            }
        }

        ///////////////////////////////////////////////////////////////////////
        public SqlDataReader execute_reader(string sql, CommandBehavior behavior)
        {
            if (Util.get_setting("LogSqlEnabled", "1") == "1")
            {
                Util.write_to_log("sql=\n" + sql);
            }

            SqlConnection conn = get_sqlconnection();
            try
            {
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    conn.Open();
                    return cmd.ExecuteReader(behavior | CommandBehavior.CloseConnection);
                }
            }
            catch
            {
                conn.Close();
                throw;
            }
        }

        ///////////////////////////////////////////////////////////////////////
        public SqlDataReader execute_reader(SqlCommand cmd, CommandBehavior behavior)
        {
            log_command(cmd);

            SqlConnection conn = get_sqlconnection();
            try
            {
                cmd.Connection = conn;
                conn.Open();
                return cmd.ExecuteReader(behavior | CommandBehavior.CloseConnection);
            }
            catch
            {
                conn.Close();
                throw;
            }
            finally
            {
                cmd.Connection = null;
            }
        }

        ///////////////////////////////////////////////////////////////////////
        public DataSet get_dataset(string sql)
        {

            if (Util.get_setting("LogSqlEnabled", "1") == "1")
            {
                Util.write_to_log("sql=\n" + sql);
            }

            DataSet ds = new DataSet();
            using (SqlConnection conn = get_sqlconnection())
            {
                SqlDataAdapter da = new SqlDataAdapter(sql, conn);
                da.Fill(ds);
                return ds;
            }
        }

        ///////////////////////////////////////////////////////////////////////
        public SqlConnection get_sqlconnection()
        {

            connection_string = Util.get_setting("ConnectionString", "MISSING CONNECTION STRING");
            SqlConnection sqlconn = new SqlConnection(connection_string);
            return sqlconn;

        }

        ///////////////////////////////////////////////////////////////////////
        public DataView get_dataview(string sql)
        {
            DataSet ds = get_dataset(sql);
            return new DataView(ds.Tables[0]);
        }


        ///////////////////////////////////////////////////////////////////////
        public DataRow get_datarow(string sql)
        {
            DataSet ds = get_dataset(sql);
            if (ds.Tables[0].Rows.Count != 1)
            {
                return null;
            }
            else
            {
                return ds.Tables[0].Rows[0];
            }
        }

        ///////////////////////////////////////////////////////////////////////
        public void log_command(SqlCommand cmd)
        {
            if (Util.get_setting("LogSqlEnabled", "1") == "1")
            {
                StringBuilder sb = new StringBuilder();
                sb.Append("sql=\n" + cmd.CommandText);
                foreach (SqlParameter param in cmd.Parameters)
                {
                    sb.Append("\n  ");
                    sb.Append(param.ParameterName);
                    sb.Append("=");
                    if (param.Value == null || Convert.IsDBNull(param.Value))
                    {
                        sb.Append("null");
                    }
                    else if (param.SqlDbType == SqlDbType.Text || param.SqlDbType == SqlDbType.Image)
                    {
                        sb.Append("...");
                    }
                    else
                    {
                        sb.Append("\"");
                        sb.Append(param.Value);
                        sb.Append("\"");
                    }
                }
                Util.write_to_log(sb.ToString());
            }
        }

    } // end DbUtil

} // end namespace