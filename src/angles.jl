function compute_angles_function!(j, D, draws, number_of_draws, angles, angles_sq, angles_vector_values, N, b, angles_folder, angles_sq_folder, chain_id, total_angles_already_stored=0)

  all_angles = zeros(Float64, number_of_draws, 20)
  all_squared_angles = zeros(Float64, number_of_draws, 20)

  for i = 1:20

    for n = 1:number_of_draws

      @inbounds all_angles[n, i] = angles_vector_values[1][j][draws[n, i]] * draws[n, 21]
      @inbounds all_squared_angles[n, i] = angles_vector_values[2][j][draws[n, i]] * draws[n, 21]

    end

    @inbounds angles[i] = sum_kbn(all_angles[:, i]) / (N - b)
    @inbounds angles_sq[i] = sum_kbn(all_squared_angles[:, i]) / (N - b)

  end

  @save "$(angles_folder)/angles_chain=$(chain_id + total_angles_already_stored).jld2" angles
  @save "$(angles_sq_folder)/angles_sq_chain=$(chain_id + total_angles_already_stored).jld2" angles_sq

end





function compute_angles_pseudo_correlations_function!(j, d, draws, number_of_draws, angles_pseudo_correlations, angles_vector_values, N, b, angles_pseudo_correlations_folder, chain_id, total_angles_pseudo_correlations_already_stored=0)

  all_angles_pseudo_correlations_for_two_specific_nodes = zeros(Float64, number_of_draws, 20)

  for column = 1:20, row = column:20

    for n = 1:number_of_draws
      @inbounds all_angles_pseudo_correlations_for_two_specific_nodes[n] = angles_vector_values[1][j][draws[n, row]] * angles_vector_values[1][j][draws[n, column]] * draws[n, 21]
    end

    @inbounds angles_pseudo_correlations[row, column] = sum_kbn(all_angles_pseudo_correlations_for_two_specific_nodes[:]) / (N - b)

  end

  for i = 1:20, j = (i+1):20 # This cycle symmetrizes 
    @inbounds angles_pseudo_correlations[i, j] = angles_pseudo_correlations[j, i]
  end

  @save "$(angles_pseudo_correlations_folder)/angles_pseudo_correlations_chain=$(chain_id + total_angles_pseudo_correlations_already_stored).jld2" angles_pseudo_correlations

end





function angles_assemble(conf::Configuration, chains_to_assemble::Int64)

  angles_all_chains = zeros(Float64, 20, chains_to_assemble)
  angles_sq_all_chains = zeros(Float64, 20, chains_to_assemble)
  angles_numerical_fluctuations = zeros(Float64, 3)

  angles_spread = zeros(Float64, 20)

  for id_chain = 1:chains_to_assemble

    @load "$(conf.angles_folder)/angles_chain=$(id_chain).jld2" angles
    @load "$(conf.angles_sq_folder)/angles_sq_chain=$(id_chain).jld2" angles_sq

    angles_all_chains[:, id_chain] = angles[:]
    angles_sq_all_chains[:, id_chain] = angles_sq[:]

  end

  # average_angle_first_node 
  angles_numerical_fluctuations[1] = mean(angles_all_chains[1, :])

  # std_dev_angle_first_node 
  angles_numerical_fluctuations[2] = std(angles_all_chains[1, :])

  # number of combined chains
  angles_numerical_fluctuations[3] = chains_to_assemble

  angles_all_chains = sum(angles_all_chains, dims=2)
  angles_sq_all_chains = sum(angles_sq_all_chains, dims=2)
  angles_all_chains[:] ./= chains_to_assemble
  angles_sq_all_chains[:] ./= chains_to_assemble

  for i = 1:20
    angles_all_chains[i] = round(angles_all_chains[i], digits=5)
    angles_sq_all_chains[i] = round(angles_sq_all_chains[i], digits=5)
  end

  angles_all_chains = vec(angles_all_chains) # otherwise dataframe it's impossible to create
  angles_sq_all_chains = vec(angles_sq_all_chains)

  angles_dataframe = DataFrame(to_rename=angles_all_chains)
  angles_sq_dataframe = DataFrame(to_rename=angles_sq_all_chains)
  angles_numerical_fluctuations_dataframe = DataFrame(to_rename=angles_numerical_fluctuations)
  column_name = "j=$(conf.j)"
  rename!(angles_dataframe, :to_rename => column_name) # julia is weird
  rename!(angles_sq_dataframe, :to_rename => column_name)
  rename!(angles_numerical_fluctuations_dataframe, :to_rename => column_name)

  angles_table_name = "/angles_$(chains_to_assemble)_chains_combined.csv"
  angles_sq_table_name = "/angles_sq_$(chains_to_assemble)_chains_combined.csv"
  angles_numerical_fluctuations_table_name = "/angles_numerical_fluctuations_$(chains_to_assemble)_chains_combined.csv"

  angles_table_full_path = conf.tables_folder * angles_table_name
  angles_sq_table_full_path = conf.tables_folder * angles_sq_table_name
  angles_numerical_fluctuations_full_path = conf.tables_folder * angles_numerical_fluctuations_table_name

  CSV.write(angles_table_full_path, angles_dataframe)
  CSV.write(angles_sq_table_full_path, angles_sq_dataframe)
  CSV.write(angles_numerical_fluctuations_full_path, angles_numerical_fluctuations_dataframe)

  # spread is here
  # I compute spread by combining squared and angles which were previously combined between multiple chains
  angles_spread[:] .= sqrt.(angles_sq_all_chains[:] - angles_all_chains[:] .^ 2)

  @save "$(conf.angles_spread_folder)/angles_spread_$(chains_to_assemble)_chains_combined.jld2" angles_spread

  angles_spread_dataframe = DataFrame(to_rename=angles_spread)
  rename!(angles_spread_dataframe, :to_rename => column_name)

  angles_spread_table_name = "/angles_spread_$(chains_to_assemble)_chains_combined.csv"
  angles_spread_table_full_path = conf.tables_folder * angles_spread_table_name

  CSV.write(angles_spread_table_full_path, angles_spread_dataframe)

  return angles_dataframe, angles_spread_dataframe, angles_numerical_fluctuations_dataframe

end





function angles_correlations_assemble(conf::Configuration, chains_to_assemble::Int64)

  angles_table_name = "/angles_$(chains_to_assemble)_chains_combined.csv"
  angles_table_full_path = conf.tables_folder * angles_table_name
  angles_all_chains = vec(Matrix(DataFrame(CSV.File(angles_table_full_path))))

  angles_pseudo_correlations_all_chains = zeros(Float64, 20, 20, chains_to_assemble)

  for id_chain = 1:chains_to_assemble

    @load "$(conf.angles_pseudo_correlations_folder)/angles_pseudo_correlations_chain=$(chain_id).jld2" angles_pseudo_correlations

    angles_pseudo_correlations_all_chains[:, :, id_chain] = angles_pseudo_correlations[:, :]

  end

  angles_pseudo_correlations_all_chains = sum(angles_pseudo_correlations_all_chains, dims=3)
  angles_pseudo_correlations_all_chains[:] ./= chains_to_assemble

  # trick to make disappear the third fictitious dimension (20×20×1 Array{Float64, 3} ---> 20×20 Matrix{Float64})
  angles_pseudo_correlations_all_chains = angles_pseudo_correlations_all_chains[:, :]

  for i = 1:20, j = 1:20
    @inbounds angles_pseudo_correlations_all_chains[j, i] = round(angles_pseudo_correlations_all_chains[j, i], digits=5)
  end

  @load "$(conf.angles_spread_folder)/angles_spread_$(chains_to_assemble)_chains_combined.jld2" angles_spread

  # we have everything to compute full correlations

  angles_correlations = zeros(Float64, 20, 20)

  for i = 1:20, j = 1:20
    @inbounds angles_correlations[j, i] = (angles_pseudo_correlations_all_chains[j, i] - angles_all_chains[i] * angles_all_chains[j]) / (angles_spread[j] * angles_spread[i])
  end

  @save "$(conf.angles_correlations_folder)/angles_correlations_$(chains_to_assemble)_chains_combined.jld2" angles_correlations

  angles_correlations_vector = reshape(angles_correlations, :)

  angles_correlations_dataframe = DataFrame(to_rename=angles_correlations_vector)
  column_name = "j=$(conf.j)"
  rename!(angles_correlations_dataframe, :to_rename => column_name)

  angles_correlations_table_name = "/angles_correlations_$(chains_to_assemble)_chains_combined.csv"
  angles_correlations_table_full_path = conf.tables_folder * angles_correlations_table_name

  CSV.write(angles_correlations_table_full_path, angles_correlations_dataframe)

  return angles_correlations_dataframe

end
