#===============================================================================
# Global Battle Agency / Online Trading
#===============================================================================

module GlobalBattleAgency
  API_URL = "https://global-battle-agency.kirbywithaz.workers.dev"

  def self.get_master_key
    # Correct for v21.1 - combines Name and the 32-bit ID
    return "#{$player.name}_#{$player.id}"
  end

  # DEPOSIT: Sends Pokemon to Cloud and removes from party
  def self.upload_pokemon(slot = 0)
    pkmn = $player.party[slot]
    return pbMessage(_INTL("No Pokemon found in slot {1}!", slot + 1)) if !pkmn
    return pbMessage(_INTL("You can't deposit your last Pokemon!")) if $player.party.length <= 1

    # Marshal DNA packing
    pokemon_dna = [Marshal.dump(pkmn)].pack("m0")

    payload = {
      "id"   => self.get_master_key,
      "data" => pokemon_dna
    }

    pbMessage(_INTL("Sending {1} to the GBA cloud...", pkmn.name))

    begin
      response = HTTPLite.post("#{API_URL}/save", payload)
      if response[:body] && response[:body].include?("OK")
        # ONLY delete from party if the cloud successfully saved it
        $player.party.delete_at(slot)
        pbMessage(_INTL("Success! {1} has been moved to the cloud.", pkmn.name))
      else
        pbMessage(_INTL("The cloud is full! Try again later."))
      end
    rescue Exception => e
      echoln "GBA Error: #{e.message}"
      pbMessage(_INTL("Failed to connect to the GBA cloud."))
    end
  end

  # WITHDRAW: Pulls Pokemon from Cloud and deletes the cloud copy
  def self.download_pokemon
    return pbMessage(_INTL("Your party is full!")) if $player.party_full?
    
    pbMessage(_INTL("Accessing the GBA cloud..."))
    id = self.get_master_key
    
    begin
      # 1. Ask for the data
      response = HTTPLite.get("#{API_URL}/get?id=#{id}")
      data = response[:body]

      if data && data != "NOT_FOUND" && !data.include?("Error")
        # 2. Re-create the Pokemon from DNA
        decoded_data = data.unpack("m0")[0]
        pkmn = Marshal.load(decoded_data)
        
        # 3. Add to party
        pbAddPokemon(pkmn)
        
        # 4. Anti-Cloning: Tell the server to delete the cloud copy
        HTTPLite.get("#{API_URL}/delete?id=#{id}")
        
        pbMessage(_INTL("Welcome back, {1}!", pkmn.name))
      else
        pbMessage(_INTL("No Pokemon found in the cloud for {1}.", $player.name))
      end
    rescue Exception => e
      echoln "GBA Error: #{e.message}"
      pbMessage(_INTL("Connection failed!"))
    end
  end
end
