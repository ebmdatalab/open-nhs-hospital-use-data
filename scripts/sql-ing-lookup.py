#%%
# Define function to query details for ingredients
def scmd_ingredient_query(ingredient_list, str_to_lower = True, wildcards = "both"):
    '''
    Define SQL query searching for all ingredients specified in 'ingredient_list'.
    The returned data includes the following columns:
    
    Arguments:
    ingredient_list {list of strings}: for example ["drug1", "drug2", "drug3"]
    wildcards {string}: "prefix", "suffix", "both", "none"
    '''
    # Define initial SQL query needed to query and join data
    sql_query_start_l1 = "SELECT 'vmp' AS type, CAST(vmp.id AS STRING) AS id, bnf_code, vmp.nm, ing.nm AS ingredient, ddd.ddd FROM dmd.vmp\n"
    sql_query_start_l2 = "INNER JOIN dmd.vpi AS vpi ON vmp.id = vpi.vmp\n"
    sql_query_start_l3 = "INNER JOIN dmd.ing as ing ON ing.id = vpi.ing\n"
    sql_query_start_l4 = "LEFT JOIN dmd.ddd on vmp.id = ddd.vpid\n"

    sql_query_start = sql_query_start_l1 + sql_query_start_l2 + sql_query_start_l3 + sql_query_start_l4
    
    # Convert ingredients to lower and define object for SQL query
    if str_to_lower == True:
        ingredient_list = [ingredient.lower() for ingredient in ingredient_list]
        sql_str_lower_01 = "LOWER("
        sql_str_lower_02 = ")"
    elif str_to_lower == False:
        sql_str_lower_01 = ""
        sql_str_lower_02 = ""

    # Add wildcards as specified 
    if wildcards == "prefix":
        ingredient_list = [f"%{ingredient}" for ingredient in ingredient_list]
    elif wildcards == "suffix":
        ingredient_list = [f"{ingredient}%" for ingredient in ingredient_list]
    elif wildcards == "both":
        ingredient_list = [f"%{ingredient}%" for ingredient in ingredient_list]
    elif wildcards == "none":
        ingredient_list = ingredient_list
    else:
        raise ValueError('Second argument "wildcards" should be one of: "prefix", "suffix", "both", "none')

    # Define empty objects for loop
    sql_query_where = []
    sql_query_or = list()

    # For loop writing WHERE and OR statements 
    for index, ingredient_position in enumerate(ingredient_list):
        if index <= 0:
            sql_query_where = f"WHERE {sql_str_lower_01}ing.nm{sql_str_lower_02} LIKE LOWER({ingredient_list[0]})"
        elif index > 0:
            sql_query_or.append(f"   OR {sql_str_lower_01}ing.nm{sql_str_lower_02} LIKE LOWER({ingredient_list[index]})")

    # Join all OR statemtns together
    sql_query_or_str = "\n".join(sql_query_or)

    # Combine all parts of the query
    sql_query_return = str(sql_query_start + sql_query_where + "\n" + sql_query_or_str)

    return sql_query_return
    

#%%                 

ingredient_list_study = ["Drug 1 DDD Drug", "Drug BBB", "ccc drug 5", "a-drug-11"]

sql_query_study = create_ingredient_lookup_sql(ingredient_list = ingredient_list_study, 
                                               str_to_lower = False, 
                                               wildcards = "prefix")



# %%
# Check out raw query
sql_query_study
# %%
# Print with with nice formatting
print(sql_query_study)

# %%

# %%
