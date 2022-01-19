# %%
def scmd_ingredient_query(ingredients, str_to_lower=True, wildcards=None):
    '''
    Define function to query details for ingredients:
    SQL query searching for all ingredients specified in 'ingredients'.

    The returned data includes the following columns:

    Arguments:
    ingredients {list of strings}: for example ["drug1", "drug2", "drug3"]
    wildcards {string}: "prefix", "suffix", "both", "none"
    '''
    # Define initial SQL query needed to query and join data
    sql_query_start = ("SELECT 'vmp' AS type, CAST(vmp.id AS STRING) AS id, bnf_code, vmp.nm, ing.nm AS ingredient, ddd.ddd FROM dmd.vmp\n"
                       "INNER JOIN dmd.vpi AS vpi ON vmp.id = vpi.vmp\n"
                       "INNER JOIN dmd.ing as ing ON ing.id = vpi.ing\n"
                       "LEFT JOIN dmd.ddd on vmp.id = ddd.vpid\n")

    # Convert ingredients to lower and define objects for generating SQL query
    if str_to_lower == True:
        ingredients = [ingredient.lower() for ingredient in ingredients]
        sql_str_lower_01 = "LOWER("
        sql_str_lower_02 = ")"
    elif str_to_lower == False:
        sql_str_lower_01 = ""
        sql_str_lower_02 = ""

    # Add wildcards as specified
    if wildcards == "prefix":
        ingredients = [f"%{ingredient}" for ingredient in ingredients]
    elif wildcards == "suffix":
        ingredients = [f"{ingredient}%" for ingredient in ingredients]
    elif wildcards == "both":
        ingredients = [f"%{ingredient}%" for ingredient in ingredients]
    else:
        raise ValueError(
            'Second argument "wildcards" should be one of: "prefix", "suffix", "both", or None')

    # Define empty objects for loop
    sql_query_where = []
    sql_query_or = list()

    # For loop writing WHERE and OR statements
    for index, ingredient_position in enumerate(ingredients):
        if index <= 0:
            sql_query_where = f"WHERE {sql_str_lower_01}ing.nm{sql_str_lower_02} LIKE '{ingredients[0]}'"
        elif index > 0:
            sql_query_or.append(
                f"   OR {sql_str_lower_01}ing.nm{sql_str_lower_02} LIKE '{ingredients[index]}'")

    # Join all OR statemtns together
    sql_query_or_str = "\n".join(sql_query_or)

    # Combine all parts of the query
    sql_query_return = str(
        sql_query_start + sql_query_where + "\n" + sql_query_or_str)

    return sql_query_return

# %%


ingredients_study = ["Drug 1 DDD Drug", "Drug BBB", "ccc drug 5", "a-drug-11"]

sql_query_study = scmd_ingredient_query(ingredients=ingredients_study,
                                        str_to_lower=True,
                                        wildcards="both")

# %%
# Check out raw query
sql_query_study
# %%
# Print with with nice formatting
print(sql_query_study)

# %%

# %%
